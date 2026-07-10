/// Source of “A Cryptographic and Implementation Review of Rage”, from `papers/rage Audit/main.tex`.
const rageAuditSource = r'''
\documentclass{article}
\usepackage[utf8]{inputenc}
\usepackage{amsmath,amssymb,hyperref,xurl}
\title{A Cryptographic and Implementation Review of Rage}
\author{
    Luke Szramowski\thanks{Cypher Stack, cryptographic review}
    \and
    Joshua Babb\thanks{Cypher Stack, implementation review}
}
\date{\today}

\begin{document}
\maketitle

\tableofcontents

\section{Overview}
\subsection{Introduction}
\texttt{rage} is a Rust re-implementation of the file-encryption tool
\emph{age}.  It adds features such as a FUSE mounting helper, plugin-based
recipient and identity extensions, and extensive CLI utilities.  Because it
protects sensitive data, rigorous scrutiny of cryptographic, I/O, and build
logic is essential.

\subsection{Review goals \& methodology}
\begin{itemize}
  \item Evaluate the security guarantees of the underlying cryptographic protocol.
  \item Inspect security-critical paths for logic flaws, panics, and
        denial-of-service vectors.
%  \item Review build scripts, tests, and fuzz harnesses for supply-chain or
%        correctness issues.
  \item Evaluate error-handling, localisation, and user-facing diagnostics.
  \item Manual static analysis; no full fuzz campaigns or formal proofs.
\end{itemize}

\section{Scope}
Commit snapshot: \texttt{d7c727aef96cc007e142f5b21c0d19210154b3c7} (18 Dec 2024).  Reviewed directories:
\begin{itemize}
  \item \texttt{age-core/src}, \texttt{age/src}, \texttt{rage/src/bin},
        \texttt{rage/build.rs}
  \item Fuzz harnesses under \texttt{fuzz/*}, \texttt{fuzz-afl/*}
  \item Tests under \texttt{age/tests}, \texttt{rage/tests}
%  \item Workspace manifests and \texttt{Cargo.lock}
\end{itemize}
Third-party crates and cryptographic primitives internal to \texttt{age-core}
were treated as opaque.

\section{Summary of findings}
\begin{itemize}
  \item The underlying cryptography is sound and offers a minimum of 128-bit security if implemented correctly.
  \item The implementation is largely sound, though there are minor issues which mostly represent Denial-of-Service (DoS) vectors, specifically:
  \item Unbounded allocations in header parsing, stanza collection,
        and archive enumeration can exhaust memory.
  \item Widespread unchecked \texttt{unwrap}/\texttt{expect}/\texttt{assert}
        calls let adversarial input crash plugins or binaries.
  \item Debug/trace helpers (\texttt{AGEDEBUG=plugin}) leak plaintext or keys
        unless redacted.
  \item One active build-script flaw and fragile \texttt{OUT\_DIR} traversal
        harm reproducible builds.
  \item Fuzzing targets miss encryption paths and offer limited coverage
        (unsafe-code guards are present but still commented out).
  \item CLI tools suffer TOCTOU races, memory-heavy I/O patterns, and
        mixed-language diagnostics.
  \item Identity parsing, UID/GID handling, and packaging (duplicate or
        unpinned dependencies) introduce spoofing and supply-chain risk.
\end{itemize}

% =================== Cryptographic review =========================

\section{Cryptographic review}

\indent The cryptographic process contained in Rage is remarkably compact. The age file that is produced is generated in two parts: the header and the payload. The purpose of the header is simply to allow the recipients to decode the \textit{file key}, which is then used to decode the payload.

As such, the security guarantees of Rage are equivalent to security guarantees of the weaker of the two schemes used, those being: the method by which the recipients are wrapped and the method of encoding the payload.

The method that is used to wrap the file key for the recipients depends on the way the recipient has identified themselves (the recipient type).  In the case of the specificed X25519 recipient, the difficulty of the wrapping is equivalent to the EC-DLP, as it is effectively a ECDH.

The second core type is a passphrase encryption system which is based on Scrypt.  (It does not appear that there is any documentation regarding the process by which Scrypt performs the wrapping, outside of the code. It appears to use ChaCha20-Poly1305 to encode the file key, which can then be unwrapped with the corresponding Scrypt passphrase.)

The method that encodes the payload is ChaCha20-Poly1305, which can be decrypted by the file key, which is, itself, encrypted by one of the two methods above.  However, both methods are cryptographically secure.

As such, so long as the cryptographic hygiene detailed in the age.md markdown is adhered to, the overall scheme should not be vulnerable to the reuse nonce attacks, which is noted to be the most glaring potential weakness.

It should be noted that ED25519 possesses a high level of security ($\approx$ 128 bits), whereas ChaCha20-Poly1305 possesses a supposed 256 bits of security.  However, ChaCha20-Poly1305 has not been formally accepted by NIST and seems to require further research to consolidate results related to it.  As such, under the assumption that ChaCha20-Poly1305 does possess the aforementioned level of security, an arbitrary user can expect, at minimum, 128 bits of security when implemented with the proper guidelines respected.

% =================== Implementation review ========================

\section{Implementation review}

% =================== Core Library (C-series) ======================

\subsection{Unbounded Allocation in Header Parsing}
\paragraph{Problem}
The helper \texttt{Header::read} and its buffered/async variants
\\(\texttt{age/src/format.rs:104--129}, \texttt{age/src/format.rs:131--157},
\\\texttt{age/src/format.rs:159--187}, \texttt{age/src/format.rs:191--219}) call the \texttt{nom} parser in a loop. When the parser returns
\texttt{Incomplete(Needed::Size(n))}, the code blindly executes
\texttt{data.resize(m + n, 0)} and then \texttt{read\_exact} the additional bytes. Because \texttt{n} is attacker‐influenced and no
upper bound is enforced, a hostile file can force arbitrarily large
allocations, leading to memory‐exhaustion denial of service.
\paragraph{Recommendation}
Abort header parsing when the accumulated buffer exceeds 64\,KiB
(the limit used by the reference Go implementation) or a tighter value
mandated by project policy. Propagate a
\\\texttt{DecryptError::InvalidHeaderSize} to callers.

\subsection{Plaintext Leakage via Debug Tee}
\paragraph{Problem}
When the environment variable \texttt{AGEDEBUG=plugin} is set,
the wrapper types \texttt{DebugReader} and \texttt{DebugWriter}
(\texttt{age-core/src/io.rs:10--33}, \\\texttt{age-core/src/io.rs:38--68}) duplicate every
byte that flows through plugin IPC channels to the process’s standard
error. These streams can contain plaintext payloads, file keys, or
other secrets, exposing them to log files or terminals that may be
captured.
\paragraph{Recommendation}
Retain the debugging feature but protect it behind a compile-time
\texttt{\#\![cfg(debug\_assertions)]} guard \emph{and} an explicit
runtime flag such as \texttt{--plugin-debug-io}. In production
builds the tee should be unreachable.

% \subsection{Identity-Parsing Error Leakage}
% \paragraph{Problem}
% `age/src/identity.rs:96–108` embeds filenames and line numbers in error
% strings, revealing file structure.
% \paragraph{Recommendation}
% Omit detailed context in release builds or behind a verbose flag.

% =================== Plugin System (P-series) =====================

\subsection{Panic on Bad Index Parsing}
\paragraph{Problem}
\texttt{wrap\_file\_key}'s error handler
(\texttt{age/src/plugin.rs:533}) and the analogous branch in
\\\texttt{IdentityPluginV1::unwrap\_stanzas}
(\texttt{age/src/plugin.rs:705}) parse an index with
\texttt{.parse().unwrap()}, panicking when a malicious plugin sends a
non-numeric value.
\paragraph{Recommendation}
Return \texttt{PluginError::Other} on \texttt{Err(e)} and propagate it;
do not unwrap.

\subsection{Panic on Stanza-Count Mismatch}
\paragraph{Problem}
The helper \texttt{recipient::run\_v1} in the plugin-support crate
\\(\texttt{age-plugin/src/recipient.rs:453}) validates the number of stanzas
returned by a plugin using
\\\texttt{assert\_eq!(stanzas.len(),\;expected\_stanzas)}.  A faulty or malicious
plugin can violate this expectation and cause the \emph{plugin process} to
panic, aborting the encryption workflow and denying service to the caller.
\paragraph{Recommendation}
Replace the assertion with a checked comparison that, on mismatch, returns a
\texttt{recipient::Error::Internal} (or similar) via the IPC channel.  The
client can then surface a graceful \texttt{EncryptError::Plugin} instead of
observing an abrupt plugin crash.

\subsection{Panic on Duplicate File-Key Delivery}
\paragraph{Problem}
Duplicate ``file-key'' commands cause
\\\texttt{assert!(file\_key.is\_none())} in
\texttt{age/src/plugin.rs:694–699}, crashing the client on malformed
plugin output.
\paragraph{Recommendation}
Ignore surplus keys or surface an error without panicking.

\subsection{\texttt{default\_for\_plugin} Should Be Fallible}
\paragraph{Problem}
\texttt{Identity::default\_for\_plugin} (\texttt{age/src/plugin.rs:194})
panics on an invalid plugin name despite a \texttt{TODO} comment.
\paragraph{Recommendation}
Return \texttt{Result<Self, Error>} instead of panicking.

\subsection{Ambiguous HRP Parsing Allows Spoofing}
\paragraph{Problem}
\texttt{Identity::from\_str} (\texttt{age/src/plugin.rs:165–174})
uses \\\texttt{trim\_end\_matches('-')} before validating the plugin
name.  Inputs such as \texttt{AGE-PLUGIN-FOO--} collapse to
\texttt{FOO}, and even an empty name passes validation, enabling
identity-name spoofing.
\paragraph{Recommendation}
Require exactly one terminating ``-'' and reject empty names.

\subsection{Unbounded Vector Growth in Stanza Collection}
\paragraph{Problem}
\texttt{Connection::unidir\_receive}
\\(\texttt{age-core/src/plugin.rs:229--279}) appends every stanza to in-memory
vectors with no upper bound.  A misbehaving peer can stream arbitrary
data and exhaust memory.
\paragraph{Recommendation}
Impose hard per-phase caps (e.g.\ 1\,024 stanzas or 8 MiB total) and
abort on excess.

% \subsection{Secret Leakage via \texttt{AGEDEBUG=plugin}}
% \paragraph{Problem}
% Debug mode echoes raw \texttt{FileKey} bytes to \texttt{stderr}.
% \paragraph{Recommendation}
% Redact or require an additional flag such as\\
% \texttt{AGEDEBUG=plugin+raw}.
% See: Plaintext Leakage via Debug Tee

% \subsection{Bitwise OR Used for Boolean Logic}
% \paragraph{Problem}
% `age/src/plugin.rs:34` uses \texttt{|} instead of \texttt{||} in
% \texttt{valid\_plugin\_name}.
% \paragraph{Recommendation}
% Switch to logical OR for clarity.

% =================== Main Binaries (M-series) =====================


\subsection{Path-Processing Panics in FUSE Helpers}
\paragraph{Problem}
Several helper functions dereference paths with unconditional \\\texttt{unwrap}/\texttt{expect}:
\begin{itemize}
  \item \texttt{tar\_path} (\texttt{rage/src/bin/rage-mount/tar.rs:13}) uses
        \\\texttt{strip\_prefix("/").unwrap()}.
  \item \texttt{zip\_path} (\texttt{rage/src/bin/rage-mount/zip.rs:12}) does the same.
  \item \texttt{add\_to\_dir\_map} in \texttt{tar.rs:89--98} relies on
        \texttt{file\_name().expect(..)} \\and \texttt{parent().expect(..)}.
  \item \texttt{getattr} in \texttt{zip.rs:149--152} converts a \texttt{Path} to UTF-8 with
        \\\texttt{to\_str().unwrap()}, panicking on non-UTF-8 names.
\end{itemize}
A crafted archive or malformed FUSE request can crash the filesystem, producing a denial of
service.
\paragraph{Recommendation}
Replace each panic with a fallible branch that returns \texttt{libc::ENOENT},
\texttt{EILSEQ}, or another suitable error so the process remains alive.

\subsection{Hard-Coded UID/GID in File Attributes}
\paragraph{Problem}
Ownership is fixed at \texttt{uid = gid = 1000}.
\begin{itemize}
  \item Synthetic root directory in \texttt{tar.rs:67--81}.
  \item All ZIP entries in \texttt{zip.rs:37--41} and \texttt{46--59}.
\end{itemize}
On multi-user systems this mis-attributes files and can bypass or block permission checks.
\paragraph{Recommendation}
When archive metadata records ownership, propagate it; otherwise retrieve the caller’s
effective IDs with \\\texttt{libc::geteuid()} and \texttt{libc::getegid()}, or provide a CLI
override.

% \subsection{TOCTOU in Input/Output Path Equality Check}
% \paragraph{Problem}
% Before starting encryption or decryption the binary checks whether \texttt{--input} and
% \texttt{--output} refer to the same file by comparing their \\\texttt{canonicalize()}d paths
% (\texttt{rage/src/bin/rage/main.rs:404--414}).  The output file is not opened until
% \texttt{OutputWriter::new} is called later, giving an attacker a window to swap a symlink
% between the check and the open, potentially truncating or overwriting the input.
% \paragraph{Recommendation}
% Open the input file first, capture its device/inode via \texttt{metadata()}, then call
% \texttt{OpenOptions::create\_new} (or equivalent) on the output path and compare the resulting
% inode pair; abort on equality.  This removes the race without deferring file creation.

% \subsection{Inefficient ZIP File Lookup}
% \paragraph{Problem}
% \texttt{open()} for ZIP archives (\texttt{zip.rs:200–213}) performs a linear
% scan of every entry on each open, yielding $O(MN)$ behaviour for $N$ opens of
% an $M$-entry archive.
% \paragraph{Recommendation}
% During mount, build a \texttt{HashMap<PathBuf, usize>} that maps file paths to
% their index, giving $O(1)$ average-case lookup.

% \subsection{Memory-Heavy Offset Handling in ZIP Read}
% \paragraph{Problem}
% The read handler (\texttt{zip.rs:225–249}) allocates an intermediate buffer of
% length \texttt{offset} to skip ahead, so a small read at offset 5 GiB creates a
% 5 GiB vector and stalls I/O.
% \paragraph{Recommendation}
% Use \texttt{ZipFile::seek} (available since \texttt{zip 1.1}) or
% \\\texttt{Read::seek} on the underlying reader to reposition without
% materialising the gap in memory.

\subsection{Unbounded Archive Enumeration}
\paragraph{Problem}
Both \texttt{AgeTarFs::open} (\texttt{tar.rs:120–139}) and
\\\texttt{AgeZipFs::open} (\texttt{zip.rs:95–114}) load every entry into
in-memory maps at mount time.  A hostile archive containing millions of tiny
files can exhaust memory.
\paragraph{Recommendation}
Impose a configurable hard limit on the number of entries or total metadata
size (e.g.\ 100 000 entries or 64 MiB).  For large archives, switch to lazy
population of directory listings.

% \subsection{Platform-Skewed Passphrase Error Handling}
% \paragraph{Problem}
% Interactive passphrase mode is blocked when input is taken from stdin, but
% only on non-Unix platforms via \texttt{#[cfg(not(unix))]} guards at
% \texttt{rage/src/bin/rage/main.rs:140–145} and \texttt{324–329}.  The same
% CLI invocation therefore yields different behaviour on Linux vs.\ Windows,
% confusing users and automated tests.
% \paragraph{Recommendation}
% Move the validation logic outside conditional compilation so that all
% platforms reject the problematic combination uniformly and emit the same
% \texttt{PassphraseWithoutFileArgument} diagnostic.

% =================== CLI Utilities (U-series) =====================

% \subsection{TOCTOU Race in Lazy Output Creation}
% \paragraph{Problem}
% \texttt{age/src/cli\_common/file\_io.rs:OutputWriter::new} defers file creation,
% allowing replacement attacks.
% \paragraph{Recommendation}
% Use \texttt{OpenOptions::create\_new}.

% \subsection{Symlink Exposure on Overwrite in Lazy Output Creation}
% \paragraph{Problem}
% When \texttt{allow\_overwrite == true}, \texttt{LazyFile::get\_file}
% (\texttt{age/src/cli\_common/file\_io.rs:287--312}) opens the target with
% \texttt{create(true).truncate(true)} after an earlier existence check in
% \texttt{OutputWriter::new}.  This sequence is safe against overwrite‐
% prevention races, but it still follows symlinks, so an attacker who can
% swap a path to a sensitive file between the CLI’s argument parsing and the
% first write may cause unintended truncation or disclosure.
% \paragraph{Recommendation}
% Open the file immediately when overwrite is requested, using the
% \texttt{O\_NOFOLLOW} (or platform-equivalent) flag together with
% \texttt{create\_new(true)}; or document that the tool intentionally allows
% symbolic-link following in this mode.

\subsection{UTF-8 Heuristic Fails on Split Sequences}
\paragraph{Problem}
\texttt{StdoutWriter::write} (\texttt{file\_io.rs:205--267}) aborts when
\\\texttt{from\_utf8(data)} fails while \emph{OutputFormat} is
\emph{Unknown}.  A valid multi-byte UTF-8 code-point split across two
writes therefore yields an \texttt{InvalidInput} error and interrupts
otherwise correct output.
\paragraph{Recommendation}
Maintain incremental decoder state (e.g.\ via
\\\texttt{encoding\_rs::Decoder}) or require callers to specify
\emph{Text} vs.\ \emph{Binary} explicitly, eliminating the heuristic.

\subsection{Root-Cause Loss in Recipient-File Parsing}
\paragraph{Problem}
In \texttt{read\_recipients\_list}
\\(\texttt{age/src/cli\_common/recipients.rs:90--122}) every parsing failure
is collapsed into \texttt{ReadError::InvalidRecipientsFile\{\,line\_number\,\}},
discarding the specific error that explains why a recipient was invalid.
\paragraph{Recommendation}
Return the underlying \texttt{ReadError} via \texttt{source()} chaining, or
wrap it in a richer variant that callers can inspect.

% \subsection{Non-Exhaustive \texttt{unreachable!()} Arms}
% \paragraph{Problem}
% `recipients.rs:194, 219` and `identities.rs:41` assume fixed enum variants.
% \paragraph{Recommendation}
% Match exhaustively and handle unknown variants gracefully.

\subsection{Silent Drop of Plugin-Recipient Parse Errors}
\paragraph{Problem}
\texttt{parse\_recipient} (\texttt{recipients.rs:72--76}) converts
\\\texttt{s.parse::<plugin::Recipient>()} with \texttt{.ok()}, silently
discarding the \\\texttt{plugin::ParseError} and reducing diagnostics to a
generic \texttt{InvalidRecipient}.
\paragraph{Recommendation}
Return \\\texttt{Result<Option<plugin::Recipient>, ReadError>} and introduce
a \\\texttt{ReadError::PluginRecipientParse\{ source \}} variant so that
callers can surface the exact failure.

\subsection{Incomplete Error-Source Chaining}
\paragraph{Problem}
\texttt{ReadError::source()} (\texttt{error.rs:117--123}) forwards only the
inner \texttt{io::Error}; wrapped errors such as
\texttt{EncryptedIdentities(\,DecryptError\,)} are lost, breaking error
introspection.
\paragraph{Recommendation}
Return the embedded error for every variant that encapsulates one,
matching the behaviour of idiomatic Rust error stacks.

% \subsection{Inefficient Passphrase Generation Loop}
% \paragraph{Problem}
% \texttt{cli\_common.rs:Passphrase::random} rescans the 2 048-word list ten times.
% \paragraph{Recommendation}
% Pre-split the list into a static vector and sample by index.

% \subsection{Thread-Unsafety of \texttt{StdinGuard}}
% \paragraph{Problem}
% A plain \texttt{bool} guards single use; future multithreading may race.
% \paragraph{Recommendation}
% Switch to \texttt{AtomicBool} or single-threaded actor model.

\subsection{Unbounded Buffer in TTY Output Path}
\paragraph{Problem}
The \texttt{StdoutBuffer::Buffered} variant in
\\\texttt{age/src/cli\_common/file\_io.rs:122--154} is selected whenever
\emph{both} the input and output streams are attached to a TTY, regardless of
the declared \texttt{OutputFormat}.  Each call to \texttt{write()} that would
exceed the current capacity allocates a new \texttt{Vec} of
\texttt{max(capacity * 2,\; capacity + data.len())} bytes and copies the
existing contents.  Because no upper bound is enforced, an interactive
session—e.g.\ a large ciphertext pasted into the terminal—can provoke
unbounded allocations and exhaust memory.

\paragraph{Recommendation}
Impose a hard ceiling (for example 32\,MiB) on the buffered vector.  After the
limit is reached, flush once and switch to direct streaming, or propagate an
error so callers can degrade gracefully.

% =================== Build System (B-series) ======================

% \subsection{Build Panic on Unterminated Italic Marker}
% \paragraph{Problem}
% `rage/build.rs:44--62` unwraps on an assumption about localisation strings,
% crashing builds.
% \paragraph{Recommendation}
% Emit a structured error and continue or abort gracefully.

% \subsection{Build Panic on Invalid Locale Directory}
% \paragraph{Problem}
% `rage/build.rs:234–242` unwraps on invalid directory names under \texttt{i18n}.
% \paragraph{Recommendation}
% Validate names against a whitelist before parsing.

% \subsection{Partial Localisation Coverage Leads to Mixed-\\Language Errors}
% \paragraph{Problem}
% While all help and usage text is fully localised, several error-message
% keys remain in English inside otherwise-translated files.  For instance,
% \\\texttt{err-stream-last-chunk-empty} in
% \texttt{rage/i18n/ru/rage.ftl:113--115} and its equivalents in the
% \texttt{es-AR} and \texttt{fr} bundles still contain the English wording
% ``Last STREAM chunk is empty'' rather than a Russian, Spanish, or French
% translation.  When these paths are exercised the CLI prints a hybrid of
% local language and English, which is jarring to end users.
% \paragraph{Recommendation}
% Audit every \texttt{err-*} and \texttt{warn-*} key across all locale
% files, populate missing translations, and add a CI check that fails the
% build if a new message is added to the default \texttt{en-US} template
% without corresponding entries in every shipping locale.  Where
% maintainer bandwidth is limited, fall back to the \texttt{fallback\_language}
% mechanism so that untranslated strings are obvious placeholders rather
% than silently defaulting to English.

\subsection{Fragile \texttt{OUT\_DIR} Ancestor Traversal}
\paragraph{Problem}
`rage/build.rs:507–514` ascends three ancestors from \texttt{OUT\_DIR}, relying
on Cargo internals.
\paragraph{Recommendation}
Keep generated files inside \texttt{OUT\_DIR}.

% \subsection{Duplicate Dependency Versions}
% \paragraph{Problem}
% \texttt{Cargo.lock} holds multiple versions of several crates.
% \paragraph{Recommendation}
% Enforce single-version crates via \texttt{cargo-deny} and\\
% \texttt{[patch.crates-io]}.

% \subsection{Missing Permission Hardening for Generated Files}
% \paragraph{Problem}
% Build script creates manpages and completions without adjusting permissions.
% \paragraph{Recommendation}
% Call \texttt{set\_permissions} to enforce at least \texttt{0o644}.

% =================== Tests / Fuzzing (T-series) ====================

\subsection{Unpinned Git Dependency in \texttt{libfuzzer-sys}}
\paragraph{Problem}
`fuzz/Cargo.toml:20` pulls from Git without a fixed revision.
\paragraph{Recommendation}
Depend on a crates.io release or pin the commit hash.

\subsection{Fragile Workspace Isolation for Fuzz Crates}
\paragraph{Problem}
Local \texttt{[workspace]} entries risk re-addition when a root workspace is
introduced.
\paragraph{Recommendation}
Move harnesses under \texttt{tools/fuzz} and exclude them from the root
workspace.

\subsection{\texttt{todo!()} in Test-Kit Error Variants}
\paragraph{Problem}
`age/tests/testkit.rs` leaves several variants unimplemented,
panicking on unexpected errors.
\paragraph{Recommendation}
Implement the branches or assert they are unreachable.

% \subsection{Missing \texttt{\#![forbid(unsafe\_code)]} in Fuzz Crates}
% \paragraph{Problem}
% Fuzz crates omit an unsafe-code ban.
% \paragraph{Recommendation}
% Add \texttt{\#![forbid(unsafe\_code)]} at crate root.

\subsection{Encryption and Serialization Paths Unfuzzed}
\paragraph{Problem}
Fuzz targets omit encryption, key-generation, and stream writer logic.
\paragraph{Recommendation}
Add dedicated targets and track coverage metrics.

\subsection{Narrow AFL Target Scope}
\paragraph{Problem}
`fuzz-afl/src/main.rs` exercises only header parsing.
\paragraph{Recommendation}
Provide multiple binaries or a stateful harness covering full workflows.

% \subsection{Brittle Filename-Based Expectations in Tests}
% \paragraph{Problem}
% `age/tests/testkit.rs` relies on hard-coded filename lists.
% \paragraph{Recommendation}
% Move expectations into test vectors or metadata files.

% \subsection{Duplicated \texttt{\#[test\_case]} Lists}
% \paragraph{Problem}
% Four functions repeat 150+ identical \texttt{\#[test\_case]} lines.
% \paragraph{Recommendation}
% Generate once via a macro or \texttt{include!()}.

% \subsection{Panic-Prone \texttt{unwrap()}s in \texttt{TestFile::parse}}
% \paragraph{Problem}
% Unchecked \texttt{unwrap()}s crash on malformed vectors.
% \paragraph{Recommendation}
% Propagate errors with \texttt{?} and contextual messages.

% =================== CLI Test Fixtures (L-series) ==================

% \subsection{Unhelpful Error on Missing Input}
% \paragraph{Problem}
% `tests/cmd/decrypt-missing-input.toml` expects\\
% \texttt{failed to fill whole buffer}, giving no hint about absent input.
% \paragraph{Recommendation}
% Emit a higher-level diagnostic and reserve raw I/O errors for verbose mode.

% \subsection{Platform-Skewed Passphrase Error Handling}
% \paragraph{Problem}
% Error messages differ between Windows and Unix when \texttt{--passphrase}
% is used without a file.
% \paragraph{Recommendation}
% Validate arguments before invoking \texttt{pinentry} to unify diagnostics.

\end{document}
''';
