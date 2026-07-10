/// Source of “CARROT carrot_core Implementation Audit”, from `papers/carrot_core Audit/main.tex`.
const carrotCoreAuditSource = r'''
\documentclass{article}                                                        % 
\usepackage[utf8]{inputenc}                                                    % 
\usepackage{amsmath,amssymb,hyperref,xurl}                                     % 
\title{CARROT \texttt{carrot\_core} Implementation Audit}                      % 
\author{Joshua Babb\thanks{Cypher Stack}}                                      % 
\date{\today}                                                                  % 

\begin{document}                                                               % 
\maketitle                                                                     % 

This report describes the findings of a code audit of the C++ implementation   % 
of the CARROT addressing scheme for Monero in the \texttt{carrot\_core}        %
directory of \url{https://github.com/jeffro256/monero/tree/carrot_core} as     %
of the commit hash \texttt{d9842e89}.                                          % 

\tableofcontents                                                               % 

\section{Overview}                                                             % 
\subsection{Introduction}                                                      % 
CARROT (Cryptonote Address on Rerandomizable RingCT Output                     % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L3
Transactions) is an addressing scheme for Monero that upgrades the             % 
legacy CryptoNote addressing system while preserving backward                  % 
compatibility.  It introduces a dual-scalar key hierarchy,                     % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L238
rerandomizable one-time addresses using generators $G$ and~$T$,                % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L127 https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L137
three-byte view tags for accelerated scanning, Janus attack                    % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L340 https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L496
resistance via anchor-based ephemeral key recomputation, and burning           % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L37
bug resistance via input-context binding.                                      % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L43 https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L325

The \texttt{carrot\_core} directory implements the core protocol logic:        % 
key derivation, address construction, enote building, the scan                 % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/account_secrets.cpp#L49 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/address_utils.cpp#L48 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L54
algorithm, output set finalization, and hardware device abstraction.           % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/scan.cpp#L146 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/output_set_finalization.cpp#L271 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/device.h#L104

\subsection{Audit goals \& methodology}                                        % 
\begin{itemize}                                                                % 
  \item Evaluate mathematical compliance of \texttt{carrot\_core} functions    % 
        against the CARROT specification.                                      % 
  \item Inspect cryptographic implementation for correctness and security      %
        properties.                                                            % 
%  \item Verify domain separator strings byte-for-byte.                         % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/config.h#L47
%  \item Map the enote scan algorithm (Section~8.1) to exact source             % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L464
%        locations.                                                             % 
  \item Verify the security properties specified in the CARROT                 % 
        document (Janus resistance, burning bug resistance, scan               % 
        binding, forward secrecy, and subgroup protection).                    % 
%  \item Cross-reference C++ with the Rust reference implementation             % 
%        by jeffro256 (the specification author).                               % 
%  \item Compare the \texttt{monero-jeffro256} and                              % 
%        \texttt{monero-fcmp\_pp-stage} codebases.                              % 
  \item Manual static analysis and testing, but no formal proofs.              % 
\end{itemize}                                                                  % 

\section{Scope}                                                                % 
Commit snapshot: \texttt{pq\_secure\_ki} branch of the \texttt{jeffro256/carrot} % https://github.com/jeffro256/carrot/tree/pq_secure_ki
CARROT specification repository, \texttt{carrot\_core} branch of the            %
\texttt{jeffro256/monero} Monero repository.  Reviewed directories:            % https://github.com/jeffro256/monero/tree/carrot_core
\begin{itemize}                                                                % 
  \item \texttt{carrot/}                                                       % 
  \item \texttt{monero/src/carrot\_core/}                                      % https://github.com/jeffro256/monero/tree/carrot_core/src/carrot_core
%  \item \texttt{monero-fcmp\_pp-stage/src/carrot\_core/} (update delta         % https://github.com/seraphis-migration/monero/tree/fcmp%2B% https://github.com/seraphis-migration/monero/tree/fcmp%2B%2B-stage/src/carrot_core
%        only)                                                                  % 
  \item \texttt{carrot-rs/carrot-crypto/src/} (Rust library,                   % https://github.com/jeffro256/carrot-rs/tree/master/carrot-crypto/src
        cross-reference only)                                                  % 
\end{itemize}                                                                  % 

%Analysis focused on cryptographic correctness, domain separation, and          % 
%specification alignment across the \texttt{carrot\_core} directory.            % 

\section{Summary of results}                                                   % 
\begin{itemize}                                                                % 
  \item The security properties defined in the specification were found to be  % 
        present in the implementation.                                         % 
  \item Both C++ and Rust use Blake2b keyed mode per RFC~7693; the             % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/hash_functions.cpp#L58 https://github.com/jeffro256/carrot-rs/blob/master/carrot-crypto/src/hash_functions.rs#L8
        specification notation uses concatenation syntax.  Both                % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L95
        implementations appear structurally consistent with the                % 
        specification, though equivalence is not proven here.                  % 
  \item The enote scan algorithm tracks the specification closely;             % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/scan.cpp#L190
        one specification step (Step~18) is not included but is mathematically redunant. % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L489
  \item Step~18 of the specification (prime-order subgroup membership          % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L489
        check on $K^{j\prime}_s$) is not included in either the C++            % 
        or the Rust implementation, but it is mathematically redundant.        % 
  \item All domain separator constants in \texttt{config.h} match the          % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/config.h#L47
        specification byte-for-byte.                                           % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L225
%  \item Coinbase extension paths diverge between C++ and Rust                  % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/config.h#L48 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L295
%        (different domain separators and inputs).                              % https://github.com/jeffro256/carrot-rs/blob/master/carrot-crypto/src/enote_components.rs#L191
\end{itemize}                                                                  % 

\section{Technical verification details}                                       % 

Hashing functions in \texttt{hash\_functions.cpp} call a common                % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/hash_functions.cpp#L58
\texttt{hash\_base()} that configures Blake2b with \texttt{"Monero"}           % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/hash_functions.cpp#L78 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/config.h#L44
personalization in keyed mode per RFC~7693.  \texttt{derive\_scalar}           % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/hash_functions.cpp#L141
reduces a 64-byte hash output modulo the Ed25519 subgroup order.               % 

\subsection{Key hierarchy and address derivation}                              % 
Key derivation functions in \texttt{account\_secrets.cpp} match the            % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/account_secrets.cpp#L49
specification for all secret-key derivations, and the public-key               % 
formulas match Section~5.3.  Subaddress derivation follows the                 % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L232
three-stage chain in Section~6.1 (preimage\_1, preimage\_2, scalar).           % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L272 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/address_utils.cpp#L48

\subsection{Enote construction}                                                % 
Enote utility functions in \texttt{enote\_utils.cpp} implement                 % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L54
specification Sections~7.1--7.9: ephemeral key derivation, ECDH, view tag,     % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L313 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L165 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L221
sender-receiver secret, output extensions, one-time address                    % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L256 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L284 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L295 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L317
construction and recovery, amount blinding factor, encryption masks,           % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L487 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L364 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L376
and Janus anchor special.                                                      % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L475

\subsection{Scan algorithm verification}                                       % 
The enote scan algorithm (specification Section~8.1) is implemented            % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L464
across \texttt{scan.cpp}, \texttt{scan\_unsafe.cpp}, \texttt{enote\_utils.cpp},% https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/scan.cpp#L146 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/scan_unsafe.cpp#L99
and \texttt{device\_ram\_borrowed.cpp}, distributed across coinbase,           % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/device_ram_borrowed.cpp#L52 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/scan.cpp#L190
external, and internal entry points.  Step~18 is not included; see             % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/scan.cpp#L321 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/scan.cpp#L361 https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L489
Section~\ref{sec:step18}.                                                      % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L489

\subsection{Domain separators and hash functions}                              % 
All domain separator constants in \texttt{config.h} were verified              % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/config.h#L47
against the specification.  The C++ constants include coinbase                 % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/config.h#L48
extension separators, address index preimages, and a generate-image            % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/config.h#L65 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/config.h#L71
preimage.%; the Rust reference uses a consolidated address index                 % https://github.com/jeffro256/carrot-rs/blob/master/carrot-crypto/src/domain_separators.rs#L26
%separator instead of the two preimage separators.                              % 

\subsection{Security property verification}                                    % 
\begin{itemize}                                                                % 
  \item \textbf{Janus attack resistance}: Normal Janus recomputation           % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L579
        derives $D'_e$ and verifies it against $D_e$; special Janus            % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L603
        provides a keyed-hash fallback.                                        % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L475
  \item \textbf{Burning bug resistance}: Input context is bound into           % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L284
        the sender-receiver secret derivation.                                 % 
  \item \textbf{Enote scan binding}: Different $k_v$ or                        % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L256
        $s_{\mathit{vb}}$ yield different view tags and blinding               % 
        factors.                                                               % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L364
  \item \textbf{Forward secrecy}: Internal enotes use symmetric                % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/scan.cpp#L361
        $s_{\mathit{vb}}$ (no ECDH); external enotes rely on DDH.              % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L221
  \item \textbf{Small subgroup protection}: $K_o$ is validated via             % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/output_set_finalization.cpp#L308
        \texttt{rct::isInMainSubgroup()} at output finalization.               % 
\end{itemize}                                                                  % 

\subsection{Output rules, device layer, and cross-implementation}              % 
Output finalization enforces minimum outputs, mandatory self-send,             % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/output_set_finalization.cpp#L271
$K_o$ subgroup membership, uniqueness, and deterministic sorting.              % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/output_set_finalization.cpp#L302 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/output_set_finalization.cpp#L308
Coinbase outputs also check $K_o$ subgroup membership.                         %

Four abstract device interfaces in \texttt{device.h} delegate all              % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/device.h#L104 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/device.h#L151 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/device.h#L178 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/device.h#L194
secret-key operations through virtual dispatch and include virtual destructors.% https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/device.h#L148 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/device.h#L175 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/device.h#L191 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/device.h#L206
Concrete RAM-backed implementations live in                                    % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/device_ram_borrowed.h#L46 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/device_ram_borrowed.cpp#L52
\texttt{device\_ram\_borrowed.h/.cpp}.                                         % 

Cross-implementation differences observed include coinbase domain              % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/config.h#L48
separators, address index staging (C++ three-step vs. Rust two-step),          % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/address_utils.cpp#L48 https://github.com/jeffro256/carrot-rs/blob/master/carrot-crypto/src/domain_separators.rs#L26
exception granularity, and device image key coverage.                          % 

\section{Observations}                                                         % 

\subsection{Blake2b keyed mode vs. specification notation}                     % 
The specification uses concatenation notation for hash inputs.  Both           % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L95
C++ and Rust use Blake2b keyed mode per RFC~7693.  This is structurally        % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/hash_functions.cpp#L58 https://github.com/jeffro256/carrot-rs/blob/master/carrot-crypto/src/hash_functions.rs#L8
different, but intended to implement the same domain-separated hashing         % 
semantics.                                                                     % 

\subsection{Step~18 subgroup check}                                            % 
\label{sec:step18}                                                             % 
Step~18 of the specification requires $K^{j\prime}_s$ to be in the             % https://github.com/jeffro256/carrot/blob/pq_secure_ki/carrot.md#L489
prime-order subgroup.  This check is not present in either the C++ or          % 
Rust implementation.                                                           % 

The check is mathematically redundant: $K_o$ is validated in the               % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/output_set_finalization.cpp#L308
prime-order subgroup at output finalization, and the extension                 % 
components are subgroup elements derived from scalars and generators.          % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L142
By group closure, $K^{j\prime}_s$ remains in the subgroup.                     % 

\subsection{Coinbase extension path divergence}                                % 
\label{sec:coinbase}                                                           % 
The C++ implementation uses dedicated coinbase domain separators for           % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/config.h#L48 https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/enote_utils.cpp#L295
extension scalars.  The Rust reference uses the standard extension             % https://github.com/jeffro256/carrot-rs/blob/master/carrot-crypto/src/enote_components.rs#L191
separators together with a clear commitment (blinding factor of 1).            % https://github.com/jeffro256/carrot-rs/blob/master/carrot-crypto/src/payments.rs#L129
The two implementations therefore use different domain separator               % 
strings and different inputs for coinbase extension derivation.                % 

\subsection{Comment text}                                                      % 
The comment im \texttt{derive\_bytes\_3} states a 2-byte output, but the       % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/hash_functions.cpp#L113
function produces 3 bytes.  The code is correct but the comment is not.        % 

\section{Conclusion}                                                           % 

The \texttt{carrot\_core} library closely tracks the CARROT specification.     %
Key derivations, enote constructions, scan algorithms, and domain separators   %
were checked for consistency with the specification.  The only protocol-level  %
deviation identified was the exclusion of Step~18 (redundant by construction). %
                                                                               %
Outside of the scope of \texttt{carrot\_core} itself, a divergence regarding   %
the domain separator used in the coinbase extension path was also observed     %
between the C++ \texttt{carrot\_core} and the Rust \texttt{carrot-rs}.         % https://github.com/jeffro256/monero/blob/carrot_core/src/carrot_core/config.h#L48 https://github.com/jeffro256/carrot-rs/blob/master/carrot-crypto/src/domain_separators.rs#L26

\end{document}                                                                 % 
''';
