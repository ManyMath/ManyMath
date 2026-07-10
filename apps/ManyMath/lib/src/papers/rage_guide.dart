/// Source of “Rage Guide”, from `papers/rage Audit/guide.tex`.
const rageGuideSource = r'''
% These tables need work, sorry.  See the original Markdown here:
% https://gist.github.com/sneurlax/7d47e4026cb1d296ac0a2e03bf997d55

\documentclass[11pt,a4paper]{article}
\usepackage[utf8]{inputenc}
\usepackage[margin=1in]{geometry}
\usepackage{amsmath,amsfonts,amssymb}
\usepackage{listings}
\usepackage{xcolor}
\usepackage{array}
\usepackage{booktabs}
\usepackage{tikz}
\usepackage{fancyvrb}
\usepackage{textcomp}

\lstset{
    basicstyle=\ttfamily\small,
    breaklines=true,
    frame=single,
    backgroundcolor=\color{gray!10},
    keywordstyle=\color{blue},
    commentstyle=\color{green!60!black},
    stringstyle=\color{red},
    numbers=left,
    numberstyle=\tiny,
    tabsize=2https://gist.github.com/sneurlax/7d47e4026cb1d296ac0a2e03bf997d55https://gist.github.com/sneurlax/7d47e4026cb1d296ac0a2e03bf997d55
}

\title{Rage Guide}
\author{Implementation: \texttt{rage} + \texttt{age-core}, Rust}
\date{Code Review Reference}

\begin{document}

\maketitle

\section{Overview}

\begin{center}
\begin{tikzpicture}\[node distance=1.8cm, auto, >=stealth]
% Core flow
\node\[draw, rectangle] (plaintext) {Plaintext};
\node\[draw, rectangle, right=3cm of plaintext] (stream) {STREAM\ChaCha20-Poly1305\64 KiB chunks, 12 B nonce};
\node\[draw, rectangle, right=3cm of stream] (ciphertext) {Ciphertext};

```
% Key derivation
\node[draw, rectangle, above=2.2cm of stream] (hkdf) {HKDF-SHA-256\\
salt = nonce (16 B)\\
ikm = file-key (16 B)\\
info = "payload"};
\node[draw, rectangle, above=2.2cm of hkdf] (nonce) {Nonce (random 16 B)};
\node[draw, rectangle, left=3cm of nonce] (filekey) {File-key (random 16 B)};
\node[draw, rectangle, below=2.2cm of filekey] (header) {HeaderV1\\recipient stanzas + 32 B HMAC};

% Arrows
\draw[->] (plaintext) -- (stream);
\draw[->] (stream) -- (ciphertext);
\draw[->] (hkdf) -- node[above] {payload-key (32 B)} (stream);
\draw[->] (header) -- node[left] {header.mac (32 B)} (hkdf);
\draw[->] (filekey) -- node[left] {ikm} (hkdf);
\draw[->] (nonce) -- node[right] {info} (hkdf);
\draw[->] (filekey) -- node[above] {mac\_key → HMAC key} (header);
\draw[->] (filekey) -- node[right] {file-key → wrap per recipient} (header);
```

\end{tikzpicture}
\end{center}

The nonce structure is 12 bytes: 11-byte big-endian counter concatenated with 1-bit last-chunk flag.

\section{Format and Primitive Reference}

\begin{table}[h!]
\centering
\begin{tabular}{p{3cm}p{4cm}p{8cm}}
\toprule
\textbf{Concept} & \textbf{Source (lines)} & \textbf{Description} \\
\midrule
\textbf{FileKey} (16 B) & \texttt{age-core/src/format.rs} 16--38 & Symmetric key boxed with \texttt{secrecy}; zeroized on drop \\ % https://github.com/str4d/rage/blob/d7c727aef96cc007e142f5b21c0d19210154b3c7/age-core/src/format.rs#L16-L38
\textbf{Stanza} & \texttt{age-core/src/format.rs} 46--106 & Header block wrapping FileKey for one recipient. Base64 wrapped at 64 columns \\ % https://github.com/str4d/rage/blob/d7c727aef96cc007e142f5b21c0d19210154b3c7/age-core/src/format.rs#L46-L106
\textbf{HeaderV1} & \texttt{age/src/format.rs} 23--102 & Contains stanzas + 32-byte HMAC tag (trailer) \\ % https://github.com/str4d/rage/blob/d7c727aef96cc007e142f5b21c0d19210154b3c7/age/src/format.rs#L23-L102
\textbf{mac\_key(file\_key)} & \texttt{age/src/keys.rs} & HKDF-SHA-256 (salt = ∅, label = \texttt{"header"}) → 32 B key \\ % https://github.com/str4d/rage/blob/d7c727aef96cc007e142f5b21c0d19210154b3c7/age/src/keys.rs
\textbf{AEAD helper} & \texttt{age-core/src/primitives.rs} & ChaCha20-Poly1305 with fixed zero-nonce; single-use key \\ % https://github.com/str4d/rage/blob/d7c727aef96cc007e142f5b21c0d19210154b3c7/age-core/src/primitives.rs
\textbf{HKDF helper} & same & HKDF-SHA-256, 32-byte output \\
\textbf{STREAM} & \texttt{age/src/primitives/stream.rs} & 64 KiB chunks, 16-byte tags, 12-byte nonce (88-bit counter) \\ % https://github.com/str4d/rage/blob/d7c727aef96cc007e142f5b21c0d19210154b3c7/age/src/primitives/stream.rs
\bottomrule
\end{tabular}
\caption{Core cryptographic components}
\end{table}

\textbf{Note:} Zero nonce is safe because every AEAD key (wrap-key or payload-key) is derived uniquely and used exactly once.

\section{Encryption Process}

\begin{lstlisting}[language=Rust, caption=Encryption workflow (simplified)]
// Generate file key and wrap for recipients
let file_key = new_file_key();              // 16 random bytes
let (stanzas, _labels) = recipients.map(|r| r.wrap_file_key(&file_key));
let header = HeaderV1::new(stanzas, mac_key(&file_key));
let nonce16 = Nonce::random();             // 16 B stored after header

// Derive payload key via HKDF: salt = nonce16, ikm = file_key, info = b"payload"
let payload_key = v1_payload_key(&file_key, &header, &nonce16)
                    .expect("header MAC already validated");

// Write ciphertext
header.write(out)?;
out.write_all(nonce16)?;
let mut w = Stream::encrypt(payload_key, out);
w.write_all(plaintext)?;
w.finish()?;              // MUST be called!
\end{lstlisting}

The function \texttt{v1\_payload\_key()} verifies the header MAC first, then derives the payload key as shown above.

\section{Recipient Stanza Algorithms}

\begin{table}[h!]
\centering
\small
\begin{tabular}{p{2.5cm}p{6.5cm}p{6cm}}
\toprule
\textbf{Scheme} & \textbf{Wrap Steps} & \textbf{Unwrap Checks} \\
\midrule
\textbf{X25519} native & 
1) Generate \texttt{esk/epk} (32 B) \hfill \break
2) \texttt{shared = DH(esk, recipient\_pk)}\hfill \break
3) \texttt{salt = epk || recipient\_pk} (64 B)\hfill \break
4) \texttt{wrap\_key = HKDF(salt, X25519-label, shared)}\hfill \break
5) \texttt{ciphertext = AEAD₀(wrap\_key, file\_key)} &
• Reject all-zero shared secret (constant-time)\hfill \break
• Body length 32 B (16 pt + 16 tag) \\
\midrule
\textbf{scrypt} passphrase & 
1) 16-byte random salt\hfill \break
2) \texttt{inner\_salt = label || salt}\hfill \break
3) \texttt{wrap\_key = scrypt(inner\_salt, logN, passphrase)}\hfill \break
4) AEAD₀ encrypt \texttt{file\_key} &
• Salt arg length 22 chars Base64\hfill \break
• \texttt{logN} decimal ≤ 63\hfill \break
• Body length 32 B\hfill \break
• \texttt{logN} ≤ \texttt{max\_work\_factor} \\
\midrule
\textbf{SSH-RSA} & RSA-OAEP-SHA256(label = "age-encryption.org/v1/ssh-rsa") &
• Modulus 2048 bits ≤ n ≤ 8192 bits\hfill \break
• Tag = sha256(pub)[0..4]\hfill \break
• Body length = modulus size \\
\midrule
\textbf{SSH-Ed25519} & 
Map Ed25519→Montgomery pk; generate \texttt{esk/epk}; derive \texttt{tweak = HKDF(ssh\_pub, ed25519-label)}; \texttt{shared = tweak·(esk·pk25519)}; otherwise like X25519 &
• Tag check\hfill \break
• Body length 32 B \\
\bottomrule
\end{tabular}
\caption{Recipient algorithms}
\end{table}

\textbf{Important:} Passphrase + public-key mixing is forbidden (\texttt{EncryptError::MixedRecipientAndPassphrase}). Other mixtures (e.g., X25519 + SSH) are permitted.

\section{Threat Model and Security Properties}

\begin{table}[h!]
\centering
\begin{tabular}{p{3cm}p{1.5cm}p{9cm}}
\toprule
\textbf{Property} & \textbf{Provided?} & \textbf{Notes} \\
\midrule
Confidentiality & ✓ & AEAD for payload and wrap. Modern primitives only \\
Integrity & ✓ & Poly1305 per chunk; header HMAC covers recipients + MAC-key (32 B) \\
Sender authenticity & ✗ & Anyone can synthesize new header for same recipients. Add external signatures if needed \\
Forward secrecy & One-shot & Ephemeral DH per file, but compromising recipient private key decrypts past files \\
Truncation & ✓ & Last chunk must decrypt with \texttt{last = 1}; \texttt{StreamReader} rejects otherwise \\
Multi-recipient malice & ⚠ & Any recipient can re-encrypt to subset/superset; indistinguishable to others \\
Side-channels & Partial & Constant-time secret comparisons; RSA/scrypt errors leak early \\
\bottomrule
\end{tabular}
\caption{Security analysis}
\end{table}

\section{Implementation Critical Points}

\begin{enumerate}
\item \textbf{Key lifecycle/zeroization} -- Drop implementations on \texttt{PayloadKey}, \texttt{SecretSlice}, \texttt{SecretBox}
\item \textbf{Nonce counter overflow} -- \texttt{Nonce::increment\_counter()} panics when 88-bit counter wraps (2⁸⁸ chunks ≈ 17 billion ZiB)
\item \textbf{Adaptive scrypt work-factor} -- \texttt{target\_scrypt\_work\_factor()} benchmarks locally; confirm side-channel safety and defaults
\item \textbf{Async STREAM state machines} -- Ensure \texttt{poll\_write}/\texttt{poll\_close} always progress and cannot double-encrypt or drop bytes
\item \textbf{Header parsing fuzz regressions} -- \texttt{format::read::*} parsers include legacy paths; re-fuzz with current \texttt{nom}
\item \textbf{RSA OAEP limits} -- Modulus bounds honored, OAEP label constant matches specification
\item \textbf{SSH-Ed25519 tweak math} -- HKDF-derived scalar could be zero (probability 2⁻²⁵⁶); code does not check (acceptable but notable)
\end{enumerate}

\section{Error Handling Guidelines}

\begin{itemize}
\item All AEAD/MAC failures → \texttt{DecryptError::DecryptionFailed} (single oracle)
\item Wrong passphrase → \texttt{KeyDecryptionFailed} (mapped from lower-level errors)
\item Async and sync code paths emit identical error variants
\end{itemize}

\section{Pseudocode Reference}

\begin{lstlisting}[caption=Key functions pseudocode]
# Encryptor::with_recipients
assert !recipients.is_empty()
for r in recipients {
    (stanzas_i, labels_i) = r.wrap_file_key(file_key)
    validate_labels_consistent(&labels_i)
    stanzas.push(stanzas_i)
}
header = HeaderV1::new(stanzas, mac_key(file_key))
nonce16 = random(16)
payload_key = v1_payload_key(file_key, header, nonce16)   # HKDF salt = header.mac
return Encryptor { header, nonce16, payload_key }

# Decryptor::decrypt
file_key = identities.find_map(|id| id.unwrap_stanzas(header.recipients))
            .ok_or(NoMatchingKeys)?
payload_key = v1_payload_key(file_key, header, nonce16)
return Stream::decrypt(payload_key, ciphertext_reader)
\end{lstlisting}

\section{Usage Notes and Best Practices}

\begin{itemize}
\item \textbf{Always call} \texttt{StreamWriter::finish()} (or \texttt{poll\_close()} for async) -- otherwise the final authenticated chunk is missing
\item A 16-byte nonce is unique per file. Do \textbf{not} reuse the same header + nonce pair
\item Protect long-lived private keys (no secure enclave). Rage zeroizes memory, but OS paging and core dumps still apply
\item For sender authenticity: Wrap final ciphertext with minisign/signify, or use \texttt{age-plugin-yubikey} for hardware-backed signatures
\end{itemize}

\section{Decryption Process}

\begin{lstlisting}[language=Rust, caption=Decryption workflow]
# Decryptor::decrypt
file_key = identities.find_map(|id| id.unwrap_stanzas(header.recipients))
            .ok_or(NoMatchingKeys)?
payload_key = v1_payload_key(file_key, header, nonce16)
return Stream::decrypt(payload_key, ciphertext_reader)
\end{lstlisting}

The decryption process reverses encryption: it parses the header, extracts the file key using matching identity, derives the payload key, and decrypts the stream.

\end{document}
''';
