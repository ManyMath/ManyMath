/// Source of “FCMP++ Crosswalk: Audit Locator Key”, from `papers/FCMPpp Implementation Audit/docs/crosswalk.tex`.
const fcmppImplementationAuditSource = r'''
\documentclass[11pt]{article}
\usepackage[margin=1in]{geometry}
\usepackage{hyperref,xcolor,longtable,booktabs,enumitem,listings,amsmath,amssymb}
\usepackage[T1]{fontenc}
\usepackage{setspace}
\setstretch{1.15}

\hypersetup{
  colorlinks=true,
  linkcolor=blue!60!black,
  urlcolor=blue!60!black,
  citecolor=blue!60!black
}

% ---- Permalink macros ----
\newcommand{\ghseraphis}{https://github.com/seraphis-migration/monero/blob/7dbeb59ea3ffc55579f14128b40ce0d8e29076b4}
\newcommand{\ghlink}[2]{\href{\ghseraphis/#1}{#2}}
\newcommand{\prlink}[2]{\href{https://github.com/monero-project/monero/pull/#1}{PR~\##1: #2}}

% ---- Per-PR permalink macros (primary audit targets) ----
% PR 10108: zeroCommitVartime (j-berman)
\newcommand{\prTenOneOEight}{https://github.com/j-berman/monero/blob/ede4d7faef46e74e1c88c3d616faa258889a847c}
% PR 10111: fe_batch_invert (j-berman)
\newcommand{\prTenOneOneOne}{https://github.com/j-berman/monero/blob/e15434bffa86d7a3859d2c223691602511d02b2f}
% PR 10135: fe_reduce_vartime (j-berman)
\newcommand{\prTenOneThreeFive}{https://github.com/j-berman/monero/blob/d9a76caab653033310ab6b8b2335d7c7436e6315}
% PR 10338: unbiased hash to ec (j-berman)
\newcommand{\prTenThreeThreeEight}{https://github.com/j-berman/monero/blob/275a8a16fe778594bfe7fde2b4e34193a153467c}
% PR 10342: torsion clearing (j-berman)
\newcommand{\prTenThreeFourTwo}{https://github.com/j-berman/monero/blob/7feface4d3941174a86de59af4aee629fd27ff9d}
% PR 9828: x25519 conversion (jeffro256, NOT j-berman)
\newcommand{\prNineEightTwoEight}{https://github.com/jeffro256/monero/blob/5318c1dc6c1d8953eb82e3d6b2901fea8bb12851}
% PR 10345: ed25519 -> Wei (j-berman)
\newcommand{\prTenThreeFourFive}{https://github.com/j-berman/monero/blob/a1f170e6e429b191acdb95b664fb9c73864679db}
% PR 10358: output_to_tuple (j-berman)
\newcommand{\prTenThreeFiveEight}{https://github.com/j-berman/monero/blob/f9f16c7c607bb28152c9b0a1c6b753c20b3fa6be}
% PR 10359: Rust FFI (j-berman)
\newcommand{\prTenThreeFiveNine}{https://github.com/j-berman/monero/blob/b549d491f1cb38a635d6fd5a95918776a6d37958}
% PR 10360: outputs_to_leaves (j-berman)
\newcommand{\prTenThreeSixZero}{https://github.com/j-berman/monero/blob/86a0aa46f59f53a1a96a4e239b9663e4ccd3e30d}

% ---- Source formatting ----
\newcommand{\src}[1]{\texttt{#1}}
\newcommand{\fn}[1]{\texttt{#1}}

% ---- Auditor annotations ----
\newcommand{\free}[1]{{\textcolor{red}{#1}}}

% ---- Evidence annotation macro ----
% \evidenceref{github_permalink}{test_case_name}{strength}
%   github_permalink: Full GitHub URL with commit SHA and line numbers
%   test_case_name: GTest test case name (e.g., HaclSmoke.Ed25519RFC8032Vector1)
%   strength: INDEPENDENT (RFC vector, SageMath oracle, HACL* cross-check)
%            or REGRESSION (recorded output from implementation under test)
% Renders as compact inline superscript with clickable link.
% Added: Phase 5 (INFRA-03) -- validated by tests/scripts/validate_evidence.py
\newcommand{\evidenceref}[3]{%
  \textsuperscript{\textcolor{blue!70!black}{%
    [\href{#1}{\scriptsize\texttt{#2}}%
    \,\textbar\,{\scriptsize #3}]%
  }}%
}

% ---- Evidence annotation example (uncomment to test rendering) ----
% Usage: \evidenceref{https://github.com/j-berman/monero/blob/ede4d7faef46e74e1c88c3d616faa258889a847c/src/ringct/rctOps.cpp\#L42}{ZeroCommitTests.KnownAnswer}{INDEPENDENT}

\title{FCMP++ CROSSWALK\\[4pt]\large Cryptographic Reference Organizing Source \& Specification:\\
Working Audit Locator Key}
\author{Joshua Babb}
\date{Draft -- \today}

\begin{document}
\maketitle
\tableofcontents
\clearpage

% ============================================================
\section{Pipeline Overview: Output to Leaf Tuple}
% ============================================================

The FCMP++ output-to-leaf pipeline transforms blockchain outputs into Selene curve tree leaves
through ten pull requests spanning three audit phases. The complete data flow:

\begin{enumerate}
  \item \textbf{Input:} \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.h\#L59}{\fn{OutputPair}} (Legacy or Carrot variant) --- \prlink{10358}{output\_to\_pre\_leaf\_tuple}
  \item \textbf{Torsion Clearing:} \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L57}{\fn{get\_valid\_torsion\_cleared\_point}} --- \prlink{10342}{torsion clearing} (Legacy only)
  \item \textbf{Key Image Derivation:} \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L660}{\fn{derive\_key\_image\_generator}} --- \prlink{10338}{unbiased key image generator} (biased for Legacy, unbiased for Carrot)
  \item \textbf{Tuple Assembly:} \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L58}{\fn{output\_to\_tuple}} --- \prlink{10360}{outputs\_to\_leaves} (composes steps 1--3)
  \item \textbf{Edwards Derivatives:} \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L69}{\fn{point\_to\_ed\_derivatives}} --- \prlink{10345}{ed25519 -> Wei} (extracts $1+y$, $1-y$, $(1-y) \cdot x$)
  \item \textbf{Batch Inversion:} \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\fn{fe\_batch\_invert}} --- \prlink{10111}{batch inverse} (Montgomery's trick on all derivatives)
  \item \textbf{Weierstrass Conversion:} \href{\prTenThreeFourFive/src/crypto/crypto-ops.c\#L3950}{\fn{fe\_ed\_derivatives\_to\_wei\_x\_y}} --- \prlink{10345}{ed25519 -> Wei} (uses inverted derivatives)
  \item \textbf{Selene Scalar:} \href{\prTenThreeFiveNine/src/fcmp_pp/tower_cycle.cpp\#L45}{\fn{selene\_scalar\_from\_bytes}} --- \prlink{10359}{Rust FFI} (FFI to Rust)
  \item \textbf{Leaf Assembly:} \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L155}{\fn{outputs\_to\_leaves}} --- \prlink{10360}{outputs\_to\_leaves} (orchestrates steps 4--8 with multithreading)
\end{enumerate}

Supporting PRs: \href{\prTenOneThreeFive/src/crypto/crypto-ops.c\#L3907}{\fn{fe\_reduce\_vartime}} (\prlink{10135}{field element reduction}) for field element canonicalization,
\href{\prTenOneOEight/src/ringct/rctOps.cpp\#L349}{\fn{zeroCommitVartime}} (\prlink{10108}{6x faster zero commit}) for zero-amount Pedersen commitments,
\href{\prNineEightTwoEight/src/crypto/crypto-ops.c\#L3858}{\fn{edwards\_bytes\_to\_x25519\_vartime}} (\prlink{9828}{Ed25519-to-X25519}) for Ed25519-to-X25519 conversion (used elsewhere in Monero, audited for completeness).

\clearpage

% ============================================================
\section{\href{https://github.com/seraphis-migration/monero/issues/294}{Audit request}}
% ============================================================

\href{https://github.com/seraphis-migration/monero/issues/294}{https://github.com/seraphis-migration/monero/issues/294}

% ============================================================
\section{Repository Map}
% ============================================================

Source files in \src{monero/src/} containing functions to be audited.
Links point to the PR branch code (primary audit target); functions from
multiple PRs link individually.

\begin{itemize}[leftmargin=2em,itemsep=6pt]
  \item \textbf{crypto/}
  \begin{itemize}[nosep]
    \item \href{\ghseraphis/src/crypto/crypto-ops.c}{\src{crypto-ops.c}} ---
      \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\fn{fe\_batch\_invert}},
      \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L317}{\fn{fe\_equals}},
      \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L1383}{\fn{fe\_frombytes\_vartime}},
      \href{\prTenOneThreeFive/src/crypto/crypto-ops.c\#L3907}{\fn{fe\_reduce\_vartime}},
      \href{\prTenThreeFourFive/src/crypto/crypto-ops.c\#L3950}{\fn{fe\_ed\_derivatives\_to\_wei\_x\_y}},
      \href{\prNineEightTwoEight/src/crypto/crypto-ops.c\#L3853}{\fn{ge\_p3\_to\_x25519}},
      \href{\prNineEightTwoEight/src/crypto/crypto-ops.c\#L3858}{\fn{edwards\_bytes\_to\_x25519\_vartime}}
    \item \ghlink{src/crypto/crypto-ops.h}{\src{crypto-ops.h}} --- declarations for the above
    \item \href{\prTenThreeFourFive/src/crypto/crypto-ops-data.c\#L874}{\src{crypto-ops-data.c}} ---
      \href{\prTenThreeFourFive/src/crypto/crypto-ops-data.c\#L874}{\fn{fe\_a\_inv\_3}}, \href{\prTenThreeFourFive/src/crypto/crypto-ops-data.c\#L875}{\fn{fe\_c}} constants
    \item \href{\prTenThreeThreeEight/src/crypto/crypto.cpp}{\src{crypto.cpp}} ---
      \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L612}{\fn{biased\_hash\_to\_ec}},
      \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L622}{\fn{unbiased\_hash\_to\_ec}},
      \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L660}{\fn{derive\_key\_image\_generator}}
    \item \ghlink{src/crypto/crypto.h}{\src{crypto.h}} --- \ghlink{src/crypto/crypto.h\#L355}{\fn{EC\_INV\_EIGHT}} constant
    \item \ghlink{src/crypto/blake2b.c}{\src{blake2b.c}} --- BLAKE2b implementation
      (used by \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L622}{\fn{unbiased\_hash\_to\_ec}})
  \end{itemize}

  \item \textbf{ringct/}
  \begin{itemize}[nosep]
    \item \href{\prTenOneOEight/src/ringct/rctOps.cpp}{\src{rctOps.cpp}} ---
      \href{\prTenOneOEight/src/ringct/rctOps.cpp\#L349}{\fn{zeroCommitVartime}},
      \href{\prTenOneOEight/src/ringct/rctOps.cpp\#L221}{\fn{H\_TABLE}}
    \item \href{\prTenThreeFourTwo/src/ringct/rctSigs.cpp}{\src{rctSigs.cpp}} ---
      \href{\prTenThreeFourTwo/src/ringct/rctSigs.cpp\#L1616}{\fn{verPointsForTorsion}}
    \item \ghlink{src/ringct/rctTypes.h}{\src{rctTypes.h}} --- \ghlink{src/ringct/rctTypes.h\#L80}{\fn{key}}, \ghlink{src/ringct/rctTypes.h\#L99}{\fn{ctkey}} types
  \end{itemize}

  \item \textbf{fcmp\_pp/}
  \begin{itemize}[nosep]
    \item \href{\ghseraphis/src/fcmp_pp/fcmp_pp_crypto.cpp}{\src{fcmp\_pp\_crypto.cpp}} ---
      \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L44}{\fn{clear\_torsion}},
      \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L57}{\fn{get\_valid\_torsion\_cleared\_point}},
      \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L34}{\fn{mul8\_is\_identity}},
      \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L69}{\fn{point\_to\_ed\_derivatives}},
      \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L86}{\fn{ed\_derivatives\_to\_wei\_x\_y}}
    \item \ghlink{src/fcmp_pp/fcmp_pp_crypto.h}{\src{fcmp\_pp\_crypto.h}} --- \ghlink{src/fcmp_pp/fcmp_pp_crypto.h\#L41}{\fn{EdDerivatives}} struct, declarations
    \item \href{\ghseraphis/src/fcmp_pp/curve_trees.cpp}{\src{curve\_trees.cpp}} ---
      \href{\prTenThreeFiveEight/src/fcmp_pp/curve_trees.cpp\#L55}{\fn{output\_to\_tuple}},
      \href{\prTenThreeFiveEight/src/fcmp_pp/curve_trees.cpp\#L142}{\fn{output\_to\_pre\_leaf\_tuple}},
      \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L155}{\fn{outputs\_to\_leaves}}
    \item \href{\prTenThreeFiveNine/src/fcmp_pp/tower_cycle.cpp}{\src{tower\_cycle.cpp}} ---
      \href{\prTenThreeFiveNine/src/fcmp_pp/tower_cycle.cpp\#L45}{\fn{selene\_scalar\_from\_bytes}} (C++ wrapper)
    \item \textbf{fcmp\_pp\_rust/}
    \begin{itemize}[nosep]
      \item \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/fcmp++.h}{\src{fcmp++.h}} ---
        \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/fcmp++.h\#L37}{\fn{SeleneScalar}} struct,
        C FFI declarations
      \item \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/src/lib.rs}{\src{lib.rs}} ---
        \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/src/lib.rs\#L31}{\fn{selene\_scalar\_from\_bytes}} (Rust FFI),
        \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/src/lib.rs\#L7}{\fn{ec\_elem\_from\_bytes}} macro
      \item \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/Cargo.toml}{\src{Cargo.toml}} --- Rust dependencies
      \item \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/CMakeLists.txt}{\src{CMakeLists.txt}} --- Build integration
    \end{itemize}
    \item \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.h}{\src{fcmp\_pp\_types.h}} ---
      \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.h\#L82}{\fn{OutputPair}},
      \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.h\#L74}{\fn{LegacyOutputPair}},
      \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.h\#L77}{\fn{CarrotOutputPairV1}} type hierarchy
    \item \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp}{\src{fcmp\_pp\_types.cpp}} ---
      \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp\#L39}{\fn{output\_tuple\_from\_bytes}},
      \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp\#L55}{\fn{output\_pubkey\_cref}},
      \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp\#L68}{\fn{commitment\_cref}},
      \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp\#L81}{\fn{output\_checked\_for\_torsion}},
      \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp\#L94}{\fn{use\_biased\_hash\_to\_point}}
  \end{itemize}
\end{itemize}

\clearpage

% ============================================================
\section{Audit 1a: Crypto}
% ============================================================

% ------------------------------------------------------------
\subsection{\prlink{10108}{6x faster zero commit}}
% ------------------------------------------------------------

\subsubsection*{\fn{zeroCommitVartime}}
\evidenceref{https://github.com/j-berman/monero/blob/ede4d7faef46e74e1c88c3d616faa258889a847c/src/ringct/rctOps.cpp\#L349}{ZeroCommitVartime.KnownAnswerDifferential}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenOneOEight/src/ringct/rctOps.cpp\#L349-L372}{\src{rctOps.cpp:349--372}}
  \item[Signature]
    \fn{key zeroCommitVartime(xmr\_amount amount)}
  \item[Spec]
    \href{https://www.cs.cornell.edu/courses/cs754/2001fa/129.PDF}{Pedersen commitment} $C = G + a \cdot H$;
    binary scalar decomposition using precomputed
    $\href{\prTenOneOEight/src/ringct/rctOps.cpp\#L221}{\fn{H\_TABLE}}[i] = 2^i \cdot H$.
    See \href{https://www.getmonero.org/library/Zero-to-Monero-2-0-0.pdf}{Zero to Monero} \S5.3.
  \item[Known issue]
    The original code contained \texttt{1UL << i}, which is undefined behavior for
    $i \geq 32$ on platforms with 32-bit \texttt{unsigned long}. Fixed by
    \href{https://github.com/seraphis-migration/monero/pull/119}{seraphis-migration/monero\#119}
    to \texttt{xmr\_amount(1) << i}.
  \item[Call sites]
    Used in RingCT verification and output conversion pipeline.
\end{description}

\paragraph{References.}
\begin{itemize}[nosep]
  \item \href{https://www.cs.cornell.edu/courses/cs754/2001fa/129.PDF}{Pedersen, ``Non-interactive and Information-Theoretic Secure Verifiable Secret Sharing,'' CRYPTO~'91}
  \item \href{https://www.getmonero.org/library/Zero-to-Monero-2-0-0.pdf}{Zero to Monero (2nd ed.)} --- Pedersen commitments \S5.3
  \item \href{https://github.com/seraphis-migration/monero/pull/119}{seraphis-migration/monero\#119} --- \texttt{1UL} bug fix
\end{itemize}

\subsubsection*{\fn{H\_TABLE}}
\evidenceref{https://github.com/j-berman/monero/blob/ede4d7faef46e74e1c88c3d616faa258889a847c/src/ringct/rctOps.cpp\#L221}{ZeroCommitVartime.PowersOfTwo}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenOneOEight/src/ringct/rctOps.cpp\#L221-L245}{\src{rctOps.cpp:221--245}}
  \item[Signature]
    \fn{const std::vector<ge\_cached>\& H\_TABLE()}
  \item[Spec]
    Lazy-initialized static table of 64 entries: $\fn{H\_TABLE}[i] = 2^i \cdot H$ in
    \ghlink{src/crypto/crypto-ops.h\#L72}{\fn{ge\_cached}} form. Entry~0 is the
    \href{https://www.cs.cornell.edu/courses/cs754/2001fa/129.PDF}{Pedersen} generator $H$;
    each subsequent entry doubles the previous via
    \ghlink{src/crypto/crypto-ops.c\#L1586}{\fn{ge\_p3\_dbl}}. 64 entries cover the full
    64-bit \fn{xmr\_amount} range.
\end{description}

\clearpage

% ------------------------------------------------------------
\subsection{\prlink{10111}{Batch inverse}}
% ------------------------------------------------------------

Branch \href{https://github.com/monero-project/monero/pull/10111}{\texttt{pr-10111}}, tip \href{https://github.com/j-berman/monero/commit/e15434bffa86d7a3859d2c223691602511d02b2f}{\texttt{e15434b}}.

\subsubsection*{\fn{fe\_batch\_invert}}
\evidenceref{https://github.com/j-berman/monero/blob/e15434bffa86d7a3859d2c223691602511d02b2f/src/crypto/crypto-ops.c\#L332}{FeBatchInvert.KnownAnswerVectors}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332-L364}{\src{crypto-ops.c:332--364}}
  \item[Signature]
    \fn{void fe\_batch\_invert(fe *out, const fe *in, const int n)}
  \item[Spec]
    \href{https://arxiv.org/abs/math/0208038}{Montgomery's trick} (Eisentr\"{a}ger, Lauter, Montgomery,
    CT-RSA 2003, \href{https://arxiv.org/pdf/math/0208038}{Section~2.2}):
    one inversion + $3(n-1)$ multiplications for $n$ elements.
    \href{https://ed25519.cr.yp.to/ed25519-20110926.pdf}{Ed25519} radix-$2^{25.5}$ limb representation.
  \item[Call sites]
    \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L96}{\fn{ed\_derivatives\_to\_wei\_x\_y}} (fcmp\_pp\_crypto.cpp:96),
    \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L155}{\fn{outputs\_to\_leaves}} (curve\_trees.cpp).
\end{description}

\subsubsection*{\fn{fe\_frombytes\_vartime}}
\evidenceref{https://github.com/j-berman/monero/blob/e15434bffa86d7a3859d2c223691602511d02b2f/src/crypto/crypto-ops.c\#L1383}{FeBatchInvert.SingleElement}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L1383-L1436}{\src{crypto-ops.c:1383--1436}}
  \item[Signature]
    \fn{int fe\_frombytes\_vartime(fe y, const unsigned char *s)}
  \item[Spec]
    \href{https://ed25519.cr.yp.to/ed25519-20110926.pdf}{Ed25519} \S4 field decoding
    with canonicality rejection ($\geq p$).
  \item[Call sites]
    \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L1440}{\fn{ge\_frombytes\_vartime}} (crypto-ops.c:1440),
    \href{\prTenOneThreeFive/src/crypto/crypto-ops.c\#L3907}{\fn{fe\_reduce\_vartime}} (crypto-ops.c:3911),
    \href{\prNineEightTwoEight/src/crypto/crypto-ops.c\#L3858}{\fn{edwards\_bytes\_to\_x25519\_vartime}} (crypto-ops.c:3861).
\end{description}

\subsubsection*{\fn{fe\_equals}}
\evidenceref{https://github.com/j-berman/monero/blob/e15434bffa86d7a3859d2c223691602511d02b2f/src/crypto/crypto-ops.c\#L317}{FeBatchInvert.SingleElement}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L317-L328}{\src{crypto-ops.c:317--328}}
  \item[Signature]
    \fn{int fe\_equals(const fe a, const fe b)}
  \item[Spec]
    Constant-time comparison via \ghlink{src/crypto/crypto-ops.c\#L1079}{\fn{fe\_tobytes}} + byte-compare.
    \href{https://ed25519.cr.yp.to/ed25519-20110926.pdf}{Ed25519} \S4 for canonical form.
  \item[Call sites]
    No production call sites. Used only in
    \ghlink{tests/unit_tests/crypto.cpp}{\src{tests/unit\_tests/crypto.cpp}}.
\end{description}

\paragraph{References.}
\begin{itemize}[nosep]
  \item \href{https://arxiv.org/abs/math/0208038}{Eisentr\"ager, Lauter, Montgomery, ``Fast Elliptic Curve Arithmetic and Improved Weil Pairing Evaluation,'' CT-RSA 2003} --- Montgomery's trick (\href{https://arxiv.org/pdf/math/0208038}{Section~2.2})
  \item \href{https://ed25519.cr.yp.to/ed25519-20110926.pdf}{Bernstein et al., Ed25519} --- field element encoding, radix-$2^{25.5}$ representation
\end{itemize}

\clearpage

% ============================================================
% PR #10135: fe_reduce_vartime (enriched from fragment)
% ============================================================

\subsection{\prlink{10135}{Field element reduction utility}}

\subsubsection*{\fn{fe\_reduce\_vartime}}
\evidenceref{https://github.com/j-berman/monero/blob/d9a76caab653033310ab6b8b2335d7c7436e6315/src/crypto/crypto-ops.c\#L3907}{FeReduceVartime.PreservesValue}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenOneThreeFive/src/crypto/crypto-ops.c\#L3907-L3912}{\src{crypto-ops.c:3907--3912}}
  \item[Signature]
    \fn{int fe\_reduce\_vartime(fe reduced\_f, const fe f)}
  \item[Spec]
    Bernstein et al.\ 2012 ref10: limb carry propagation and canonical reduction.
    No external specification---this is an implementation utility for normalizing
    ref10 limb representations after \fn{fe\_add}/\fn{fe\_sub}.
  \item[Algorithm]
    Serialize-deserialize round trip for canonical limb normalization:
    \fn{fe\_tobytes}$(f) \to b$; \fn{fe\_frombytes\_vartime}$(b) \to f'$.
    The serialization performs full reduction mod $p = 2^{255}-19$
    (carry propagation + conditional subtraction of $p$).
    Deserialization loads canonical bytes into fresh, tight-bounded limbs.
    Returns 0 on success, $-1$ if the byte representation is non-canonical ($\geq p$).
  \item[Constant-time]
    Variable-time (\fn{\_vartime} suffix). The \fn{fe\_frombytes\_vartime} call
    branches on whether input bytes represent a value $\geq p$.
    Acceptable: called only on public coordinate data (PR \#10345).
  \item[Dependency]
    Requires \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L1383}{\fn{fe\_frombytes\_vartime}} (\prlink{10111}{batch inverse}).
    Used by \href{\prTenThreeFourFive/src/crypto/crypto-ops.c\#L3950}{\fn{fe\_ed\_derivatives\_to\_wei\_x\_y}} (\prlink{10345}{ed25519 -> Wei}).
  \item[Integration note]
    In the mega commit, this function is renamed to \ghlink{src/crypto/crypto-ops.c\#L4078}{\fn{fe\_reduce}} and returns
    \fn{void}. See \ghlink{src/crypto/crypto-ops.c\#L4078-L4083}{mega commit version}.
  \item[Walkthrough]
    \src{fcmp-impl-audit-gsd/docs/pr10135-walkthrough.md}
\end{description}

\paragraph{References.}
\begin{itemize}[nosep]
  \item \href{https://ed25519.cr.yp.to/ed25519-20110926.pdf}{Bernstein et al., Ed25519} \S4 --- limb bound analysis
\end{itemize}

\clearpage

% ============================================================
% PR #10342: Torsion Clearing (enriched from fragment)
% ============================================================

\subsection{\prlink{10342}{FCMP++: clear torsion, torsion check}}

Branch \href{https://github.com/monero-project/monero/pull/10342}{\texttt{pr-10342}}, tip \href{https://github.com/j-berman/monero/commit/7feface4d3941174a86de59af4aee629fd27ff9d}{\texttt{7feface}}.

\subsubsection*{\fn{mul8\_is\_identity}}
\evidenceref{https://github.com/j-berman/monero/blob/7feface4d3941174a86de59af4aee629fd27ff9d/src/fcmp_pp/fcmp_pp_crypto.cpp\#L34}{Mul8IsIdentity.AllEightSmallOrderPoints}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L34-L43}{\src{fcmp\_pp\_crypto.cpp:34--43}}
    (mega: \href{\ghseraphis/src/fcmp_pp/fcmp_pp_crypto.cpp\#L248-L256}{\src{248--256}})
  \item[Signature]
    \fn{bool mul8\_is\_identity(const ge\_p3 \&point)}
  \item[Spec]
    Checks whether $8P = \mathcal{O}$ to detect small-order points (order dividing the
    cofactor $h = 8$).  Three doublings via \ghlink{src/crypto/crypto-ops.c\#L3113}{\fn{ge\_mul8}}, then identity check via
    \ghlink{src/crypto/crypto-ops.c\#L3131}{\fn{ge\_p3\_is\_point\_at\_infinity\_vartime}}: $X = 0$, $T = 0$, $Y = Z$, $Y \neq 0$
    in extended projective coordinates~(\href{https://eprint.iacr.org/2008/522}{Hisil et~al., 2008}).
  \item[CT status]
    Variable-time (uses \fn{\_vartime} identity check).  Acceptable: input points are
    public blockchain data.
  \item[Downstream]
    Called by \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L57}{\fn{get\_valid\_torsion\_cleared\_point}} (\href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L57}{\src{fcmp\_pp\_crypto.cpp:57}}).
    Indirectly used by \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L58}{\fn{output\_to\_tuple}} (\prlink{10360}{outputs\_to\_leaves}) for curve tree leaf construction.
\end{description}

\subsubsection*{\fn{clear\_torsion}}
\evidenceref{https://github.com/j-berman/monero/blob/7feface4d3941174a86de59af4aee629fd27ff9d/src/fcmp_pp/fcmp_pp_crypto.cpp\#L44}{ClearTorsion.PrimeOrderUnchanged}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L44-L55}{\src{fcmp\_pp\_crypto.cpp:44--55}}
    (mega: \href{\ghseraphis/src/fcmp_pp/fcmp_pp_crypto.cpp\#L308-L319}{\src{308--319}})
  \item[Signature]
    \fn{crypto::ec\_point clear\_torsion(const ge\_p3 \&point)}
  \item[Spec]
    Projects a point $P = P_0 + T$ onto the prime-order subgroup $\langle G \rangle$ by
    computing $8 \cdot (8^{-1} \bmod \ell) \cdot P = P_0$, where $8^{-1} \bmod \ell$ is
    the constant \fn{EC\_INV\_EIGHT} (\href{\ghseraphis/src/crypto/crypto.h\#L355}{\src{crypto.h:355}}).
    Torsion clearing per the Ristretto methodology~\cite{hamburg-ristretto}.
  \item[Algorithm]
    Step~1: \ghlink{src/crypto/crypto-ops.c\#L2952}{\fn{ge\_scalarmult}}$(P, \mathtt{EC\_INV\_EIGHT})$ -- scalar multiplication by
    $8^{-1} \bmod \ell$.
    Step~2: \ghlink{src/crypto/crypto-ops.c\#L3113}{\fn{ge\_mul8}} -- three doublings to multiply by~8.
    The composition yields $8 \cdot 8^{-1} \cdot P_0 + 8 \cdot T' = P_0 + \mathcal{O} = P_0$.
  \item[CT status]
    Variable-time (\fn{ge\_scalarmult} uses double-and-add).  Scalar is a public constant;
    point is public blockchain data.  No secrets leaked.
  \item[Downstream]
    Called by \fn{get\_valid\_torsion\_cleared\_point} (\href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L57}{\src{fcmp\_pp\_crypto.cpp:57}}).
    Downstream through \prlink{10360}{outputs\_to\_leaves} (\href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L58}{\fn{output\_to\_tuple}}) for tree leaf construction.
\end{description}

\subsubsection*{\fn{get\_valid\_torsion\_cleared\_point}}
\evidenceref{https://github.com/j-berman/monero/blob/7feface4d3941174a86de59af4aee629fd27ff9d/src/fcmp_pp/fcmp_pp_crypto.cpp\#L57}{GetValidTorsionClearedPoint.SmallOrderRejected}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L57-L67}{\src{fcmp\_pp\_crypto.cpp:57--67}}
    (mega: \href{\ghseraphis/src/fcmp_pp/fcmp_pp_crypto.cpp\#L321-L331}{\src{321--331}})
  \item[Signature]
    \fn{bool get\_valid\_torsion\_cleared\_point(const crypto::ec\_point \&point, crypto::ec\_point \&torsion\_cleared\_out)}
  \item[Spec]
    Validation pipeline for FCMP++ output processing:
    (1)~decompress via \fn{ge\_frombytes\_vartime},
    (2)~reject small-order via \fn{mul8\_is\_identity},
    (3)~clear torsion via \fn{clear\_torsion},
    (4)~reject identity.
    Ensures all points entering the curve tree are non-trivial prime-order elements.
  \item[CT status]
    Variable-time (early returns, vartime subroutines).  All inputs are public.
  \item[Downstream]
    Called by \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L58}{\fn{output\_to\_tuple}} (\prlink{10360}{outputs\_to\_leaves},
    \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L76}{\src{curve\_trees.cpp:76}})
    and \href{\prTenThreeFourTwo/src/ringct/rctSigs.cpp\#L1616}{\fn{verPointsForTorsion}} (\prlink{10342}{torsion clearing},
    \href{\prTenThreeFourTwo/src/ringct/rctSigs.cpp\#L1616}{\src{rctSigs.cpp:1616}}).
\end{description}

\subsubsection*{\fn{EC\_INV\_EIGHT} (constant)}
\evidenceref{https://github.com/seraphis-migration/monero/blob/7dbeb59ea3ffc55579f14128b40ce0d8e29076b4/src/crypto/crypto.h\#L355}{EC\_INV\_EIGHT.RoundTrip}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\ghseraphis/src/crypto/crypto.h\#L355-L364}{\src{crypto.h:355--364}}
  \item[Value]
    The scalar $8^{-1} \bmod \ell$ where $\ell = 2^{252} + 27742317777372353535851937790883648493$,
    encoded as 32~bytes little-endian.
    Verify: $8 \times \mathtt{EC\_INV\_EIGHT} \equiv 1 \pmod{\ell}$.
  \item[Used by]
    \fn{clear\_torsion} (\href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L44}{\src{fcmp\_pp\_crypto.cpp:44}}).
\end{description}

\subsubsection*{\fn{verPointsForTorsion}}
\evidenceref{https://github.com/j-berman/monero/blob/7feface4d3941174a86de59af4aee629fd27ff9d/src/ringct/rctSigs.cpp\#L1616}{GetValidTorsionClearedPoint.PrimeOrderAccepted}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFourTwo/src/ringct/rctSigs.cpp\#L1616-L1652}{\src{rctSigs.cpp:1616--1652}}
  \item[Signature]
    \fn{bool verPointsForTorsion(const std::vector<key> \& pts)}
  \item[Spec]
    Batch parallel torsion verification. Each point must satisfy: after clearing torsion,
    it equals itself (i.e., already torsion-free).
\end{description}

\paragraph{References.}
\begin{itemize}[nosep]
  \item \href{https://risencrypto.github.io/CofactorClearing/}{RisenCrypto: Cofactor Clearing}
  \item \href{https://eprint.iacr.org/2013/325}{Bernstein et al., Elligator (ePrint 2013/325)}
  \item \href{https://ed25519.cr.yp.to/ed25519-20110926.pdf}{Bernstein et al., Ed25519} --- cofactor $h = 8$
  \item \href{https://raw.githubusercontent.com/kayabaNerve/fcmp-plus-plus-paper/refs/heads/develop/fcmp%2B%2B.pdf}{FCMP++ paper} --- curve tree requirements
  \item \href{https://ristretto.group/}{Hamburg, ``The Ristretto Group''} --- torsion clearing methodology
  \item \href{https://eprint.iacr.org/2008/522}{Hisil, Wong, Carter, Dawson, ``Twisted Edwards Curves Revisited,'' ePrint 2008/522}
\end{itemize}

\clearpage

% ============================================================
% PR #10338: Unbiased Hash-to-Point (enriched from fragment)
% ============================================================

\subsection{\prlink{10338}{crypto: derive key image generator \& separate \{un\}biased hash to ec}}

Branch \href{https://github.com/monero-project/monero/pull/10338}{\texttt{pr-10338}}, tip \href{https://github.com/j-berman/monero/commit/275a8a16fe778594bfe7fde2b4e34193a153467c}{\texttt{275a8a1}}.

\subsubsection*{\fn{biased\_hash\_to\_ec}}
\evidenceref{https://github.com/j-berman/monero/blob/275a8a16fe778594bfe7fde2b4e34193a153467c/src/crypto/crypto.cpp\#L612}{BiasedVsUnbiased.DifferentOutputs}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L612-L620}{\src{crypto.cpp:612--620}}
    (mega: \href{\ghseraphis/src/crypto/crypto.cpp\#L612-L620}{\src{612--620}})
  \item[Signature]
    \fn{static void biased\_hash\_to\_ec(const public\_key \&key, ge\_p3 \&res)}
  \item[Spec]
    Original Monero hash-to-point.  Hashes public key via \ghlink{src/crypto/hash.c\#L33}{\fn{cn\_fast\_hash}}
    (Keccak-256, 32~bytes), maps to curve via Elligator~2
    (\ghlink{src/crypto/crypto-ops.c\#L2367}{\fn{ge\_fromfe\_frombytes\_vartime}})~(\href{https://eprint.iacr.org/2013/325}{Bernstein et~al., 2013}),
    then cofactor-clears with $8P$ via \ghlink{src/crypto/crypto-ops.c\#L3113}{\fn{ge\_mul8}}.
    Single Elligator application produces a biased distribution
    over the prime-order subgroup: $\sim 50\%$ of elements unreachable.
    See MRL issue~\#142 for bias analysis.
  \item[Algorithm]
    $h \leftarrow \text{cn\_fast\_hash}(K)$;
    $P \leftarrow Ell_2(h)$;
    return $8P$.
  \item[CT status]
    Variable-time (\fn{ge\_fromfe\_frombytes\_vartime} branches on Legendre symbol).
    Acceptable: input is a hash of a public key (public data).
  \item[Downstream]
    Called by \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L650}{\fn{biased\_derive\_key\_image\_generator}}
    (\href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L650}{\src{crypto.cpp:650}}).
    Used for pre-FCMP++ key image generation (legacy path).
\end{description}

\subsubsection*{\fn{unbiased\_hash\_to\_ec}}
\evidenceref{https://github.com/j-berman/monero/blob/275a8a16fe778594bfe7fde2b4e34193a153467c/src/crypto/crypto.cpp\#L622}{UnbiasedHashToEc.KnownAnswer}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L622-L648}{\src{crypto.cpp:622--648}}
    (mega: \href{\ghseraphis/src/crypto/crypto.cpp\#L622-L648}{\src{622--648}})
  \item[Signature]
    \fn{void crypto\_ops::unbiased\_hash\_to\_ec(const unsigned char *preimage, const std::size\_t length, ec\_point \&res)}
  \item[Spec]
    Unbiased hash-to-curve per \href{https://www.rfc-editor.org/rfc/rfc9380}{RFC~9380} Section~3 (``hash to two points and
    add'').  \href{https://blake2.net/blake2.pdf}{BLAKE2b} produces 64~bytes, split into two 32-byte
    halves.  Each half is mapped via \href{https://eprint.iacr.org/2013/325}{Elligator~2}
    and cofactor-cleared independently; results are added.
    Statistical distance from uniform over $\langle G \rangle$ is
    $\leq 2^{-128}$ by the Brier--Coron--Icart--Madore--Randriam--Tibouchi
    theorem~\cite{brier2010hash-to-curve}.
  \item[Algorithm]
    $(h_1 \| h_2) \leftarrow \text{BLAKE2b}(\text{preimage}, 64)$;
    $Q_1 \leftarrow 8 \cdot Ell_2(h_1)$;
    $Q_2 \leftarrow 8 \cdot Ell_2(h_2)$;
    return $H = Q_1 + Q_2$.
  \item[CT status]
    Variable-time (two \ghlink{src/crypto/crypto-ops.c\#L2367}{\fn{ge\_fromfe\_frombytes\_vartime}} calls).
    Acceptable: both Elligator inputs are hashes of public keys.
  \item[Downstream]
    Called by \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L656}{\fn{unbiased\_derive\_key\_image\_generator}}
    (\href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L656}{\src{crypto.cpp:656}}).
    FCMP++ key image generation path.
\end{description}

\subsubsection*{\fn{biased\_derive\_key\_image\_generator}}
\evidenceref{https://github.com/j-berman/monero/blob/275a8a16fe778594bfe7fde2b4e34193a153467c/src/crypto/crypto.cpp\#L650}{DeriveKeyImageGenerator.BiasedFlag}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L650-L654}{\src{crypto.cpp:650--654}}
    (mega: \href{\ghseraphis/src/crypto/crypto.cpp\#L650-L654}{\src{650--654}})
  \item[Signature]
    \fn{static void biased\_derive\_key\_image\_generator(const public\_key \&pub, ec\_point \&ki\_gen)}
  \item[Spec]
    Wrapper: calls \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L612}{\fn{biased\_hash\_to\_ec}} on the public key, compresses
    result to 32-byte \fn{ec\_point}.  Legacy Monero key image generator.
  \item[Algorithm]
    $\text{ki\_gen} \leftarrow \text{compress}(\text{biased\_hash\_to\_ec}(K))$.
  \item[Downstream]
    Called by \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L660}{\fn{derive\_key\_image\_generator}}
    (\href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L660}{\src{crypto.cpp:660}})
    when \fn{biased == true}.
\end{description}

\subsubsection*{\fn{unbiased\_derive\_key\_image\_generator}}
\evidenceref{https://github.com/j-berman/monero/blob/275a8a16fe778594bfe7fde2b4e34193a153467c/src/crypto/crypto.cpp\#L656}{DeriveKeyImageGenerator.UnbiasedFlag}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L656-L658}{\src{crypto.cpp:656--658}}
    (mega: \href{\ghseraphis/src/crypto/crypto.cpp\#L656-L658}{\src{656--658}})
  \item[Signature]
    \fn{static void unbiased\_derive\_key\_image\_generator(const public\_key \&pub, ec\_point \&ki\_gen)}
  \item[Spec]
    Wrapper: passes public key bytes as preimage to \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L622}{\fn{unbiased\_hash\_to\_ec}}.
    FCMP++ key image generator using the dual-Elligator construction.
  \item[Algorithm]
    $\text{ki\_gen} \leftarrow \text{unbiased\_hash\_to\_ec}(K_{\text{bytes}}, 32)$.
  \item[Downstream]
    Called by \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L660}{\fn{derive\_key\_image\_generator}}
    (\href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L660}{\src{crypto.cpp:660}})
    when \fn{biased == false}.
\end{description}

\subsubsection*{\fn{derive\_key\_image\_generator}}
\evidenceref{https://github.com/j-berman/monero/blob/275a8a16fe778594bfe7fde2b4e34193a153467c/src/crypto/crypto.cpp\#L660}{DeriveKeyImageGenerator.BiasedFlag}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L660-L665}{\src{crypto.cpp:660--665}}
    (mega: \href{\ghseraphis/src/crypto/crypto.cpp\#L660-L665}{\src{660--665}})
  \item[Signature]
    \fn{void crypto\_ops::derive\_key\_image\_generator(const public\_key \&pub, const bool biased, ec\_point \&ki\_gen)}
  \item[Spec]
    Boolean dispatch between legacy (biased, pre-FCMP++) and new (unbiased,
    FCMP++) hash-to-point paths.  The \fn{biased} flag is determined by
    transaction version/height.
  \item[Algorithm]
    If \fn{biased}: call \fn{biased\_derive\_key\_image\_generator}$(K)$.
    Else: call \fn{unbiased\_derive\_key\_image\_generator}$(K)$.
  \item[CT status]
    Variable-time (branches on public \fn{biased} flag).  No secrets involved.
  \item[Downstream]
    Called by \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L105}{\fn{output\_to\_tuple}} (\prlink{10360}{outputs\_to\_leaves},
    \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L105}{\src{curve\_trees.cpp:105}}).
    Also called by \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L668}{\fn{generate\_key\_image}}
    (\href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L668}{\src{crypto.cpp:668}}).
  \item[Cross-references]
    Output feeds into FCMP++ curve tree leaf construction (\prlink{10345}{ed25519 -> Wei},
    \prlink{10358}{output -> tuple}).  Depends on \prlink{10342}{torsion clearing} for the output
    keys that are hashed by this function.
\end{description}

\paragraph{References.}
\begin{itemize}[nosep]
  \item \href{https://github.com/monero-project/research-lab/issues/142}{MRL issue \#142} --- bias rationale and unbiased replacement
  \item \href{https://web.getmonero.org/resources/research-lab/pubs/ge_fromfe.pdf}{\fn{ge\_fromfe}} --- Monero's Elligator-like map
  \item \href{https://eprint.iacr.org/2013/325}{Bernstein et al., Elligator (ePrint 2013/325)} --- Elligator~2 map \S5.5
  \item \href{https://www.rfc-editor.org/rfc/rfc9380}{RFC~9380: Hashing to Elliptic Curves} --- sum-of-two-maps technique
  \item \href{https://blake2.net/blake2.pdf}{Aumasson et al., BLAKE2} --- hash used in unbiased variant
  \item \href{https://eprint.iacr.org/2009/340}{Brier, Coron, Icart, Madore, Randriam, Tibouchi, ``Efficient Indifferentiable Hashing into Ordinary Elliptic Curves,'' Crypto 2010}
\end{itemize}

\clearpage

% ============================================================
% PR #9828: Ed25519-to-X25519 Conversion (enriched from fragment)
% ============================================================

\subsection{\prlink{9828}{Ed25519-to-X25519 point conversion}}

Branch \href{https://github.com/monero-project/monero/pull/9828}{\texttt{pr-9828}}, tip \href{https://github.com/jeffro256/monero/commit/5318c1dc6c1d8953eb82e3d6b2901fea8bb12851}{\texttt{5318c1d}}.
Note: this PR is by \textbf{jeffro256}, not j-berman.

\subsubsection*{\fn{edwardsYZ\_to\_x25519} (static)}
\evidenceref{https://github.com/jeffro256/monero/blob/5318c1dc6c1d8953eb82e3d6b2901fea8bb12851/src/crypto/crypto-ops.c\#L3838}{EdwardsToX25519.KnownPairsPynacl}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prNineEightTwoEight/src/crypto/crypto-ops.c\#L3838-L3850}{\src{crypto-ops.c:3838--3850}}
  \item[Signature]
    \fn{static void edwardsYZ\_to\_x25519(unsigned char *xbytes, const fe Y, const fe Z)}
  \item[Spec]
    \href{https://cr.yp.to/ecdh/curve25519-20060209.pdf}{Bernstein 2006 ``Curve25519: new Diffie-Hellman speed records,''} Section~2:
    birational equivalence $u = (1+y)/(1-y)$.
    \href{https://www.rfc-editor.org/rfc/rfc7748}{RFC~7748}, Section~4.1: Curve25519 and Ed25519 relationship.
  \item[Algorithm]
    Projective birational map: $u = (Z + Y) \cdot (Z - Y)^{-1} \bmod p$.
    Five operations: \fn{fe\_add}, \fn{fe\_sub}, \fn{fe\_invert} (Fermat $d^{p-2}$),
    \fn{fe\_mul}, \fn{fe\_tobytes}.
    Division by zero at identity $(0,1)$ yields $u = 0$ via \fn{fe\_invert}$(0) = 0$.
  \item[Constant-time]
    Yes. All ref10 field operations are constant-time; \fn{fe\_invert} uses
    a hardcoded addition chain with no data-dependent branches.
  \item[Dependency]
    Uses standard ref10 field arithmetic. No PR dependencies.
    Consumed by \fn{ge\_p3\_to\_x25519} and \fn{edwards\_bytes\_to\_x25519\_vartime} (this PR).
  \item[Walkthrough]
    \src{fcmp-impl-audit-gsd/docs/pr9828-walkthrough.md}
\end{description}

\subsubsection*{\fn{ge\_p3\_to\_x25519}}
\evidenceref{https://github.com/jeffro256/monero/blob/5318c1dc6c1d8953eb82e3d6b2901fea8bb12851/src/crypto/crypto-ops.c\#L3853}{EdwardsToX25519.Basepoint}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prNineEightTwoEight/src/crypto/crypto-ops.c\#L3853-L3856}{\src{crypto-ops.c:3853--3856}}
  \item[Signature]
    \fn{void ge\_p3\_to\_x25519(unsigned char *xbytes, const ge\_p3 *h)}
  \item[Spec]
    Same as \fn{edwardsYZ\_to\_x25519}. Wrapper extracting $Y, Z$ from
    extended coordinates $(X : Y : Z : T)$.
  \item[Algorithm]
    Passes \verb|h->Y|, \verb|h->Z| to \fn{edwardsYZ\_to\_x25519}.
    No additional computation.
  \item[Constant-time]
    Yes (delegates to CT core function).
  \item[Dependency]
    Requires \href{\prNineEightTwoEight/src/crypto/crypto-ops.c\#L3838}{\fn{edwardsYZ\_to\_x25519}} (this PR).
    Used by Carrot protocol's \fn{ConvertPointE()}.
  \item[Walkthrough]
    \src{fcmp-impl-audit-gsd/docs/pr9828-walkthrough.md}
\end{description}

\subsubsection*{\fn{edwards\_bytes\_to\_x25519\_vartime}}
\evidenceref{https://github.com/jeffro256/monero/blob/5318c1dc6c1d8953eb82e3d6b2901fea8bb12851/src/crypto/crypto-ops.c\#L3858}{EdwardsBytesToX25519.Basepoint}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prNineEightTwoEight/src/crypto/crypto-ops.c\#L3858-L3871}{\src{crypto-ops.c:3858--3871}}
  \item[Signature]
    \fn{int edwards\_bytes\_to\_x25519\_vartime(unsigned char *xbytes, const unsigned char *s)}
  \item[Spec]
    \href{https://cr.yp.to/ecdh/curve25519-20060209.pdf}{Bernstein 2006}, Section~2 (birational map) combined with
    \href{https://www.rfc-editor.org/rfc/rfc7748}{RFC~7748}, Section~4.1 (encoding). Carrot spec \fn{ConvertPointE()}.
  \item[Algorithm]
    Deserializes 32-byte Edwards $y$-coordinate via \fn{fe\_frombytes\_vartime};
    rejects non-canonical ($y \geq p$, returns $-1$).
    Sets $Z = 1$ (affine input), delegates to \fn{edwardsYZ\_to\_x25519}.
    Returns 0 on success.
  \item[Constant-time]
    Variable-time (\fn{\_vartime} suffix). The \fn{fe\_frombytes\_vartime} call
    branches on canonical check. Core conversion after validation is CT.
    Acceptable: operates on public key data only.
  \item[Dependency]
    Requires \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L1383}{\fn{fe\_frombytes\_vartime}} (\prlink{10111}{batch inverse}) and
    \href{\prNineEightTwoEight/src/crypto/crypto-ops.c\#L3838}{\fn{edwardsYZ\_to\_x25519}} (this PR).
  \item[Walkthrough]
    \src{fcmp-impl-audit-gsd/docs/pr9828-walkthrough.md}
\end{description}

\paragraph{References.}
\begin{itemize}[nosep]
  \item \href{https://cr.yp.to/ecdh/curve25519-20060209.pdf}{Bernstein, Curve25519} --- Montgomery form definition, birational equivalence
  \item \href{https://ed25519.cr.yp.to/ed25519-20110926.pdf}{Bernstein et al., Ed25519} --- twisted Edwards / Montgomery equivalence
  \item \href{https://www.rfc-editor.org/rfc/rfc7748}{RFC~7748}, Section~4.1 --- Curve25519 and Ed25519 relationship
\end{itemize}

\clearpage

% ============================================================
% PR #10345: Ed25519-to-Weierstrass Conversion (enriched from fragment)
% ============================================================

\subsection{\prlink{10345}{FCMP++: Ed25519-to-Weierstrass conversion}}

Branch \href{https://github.com/monero-project/monero/pull/10345}{\texttt{pr-10345}}, tip \href{https://github.com/j-berman/monero/commit/a1f170e6e429b191acdb95b664fb9c73864679db}{\texttt{a1f170e}}.

\subsubsection*{\fn{fe\_ed\_derivatives\_to\_wei\_x} (static)}
\evidenceref{https://github.com/j-berman/monero/blob/a1f170e6e429b191acdb95b664fb9c73864679db/src/crypto/crypto-ops.c\#L3937}{PointToWeiXY.KnownAnswerVectors}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFourFive/src/crypto/crypto-ops.c\#L3937-L3948}{\src{crypto-ops.c:3937--3948}}
  \item[Signature]
    \fn{static void fe\_ed\_derivatives\_to\_wei\_x(unsigned char *wei\_x, const fe inv\_one\_minus\_y, const fe one\_plus\_y)}
  \item[Spec]
    \href{https://www.ietf.org/archive/id/draft-ietf-lwig-curve-representations-02.pdf}{IETF draft-ietf-lwig-curve-representations-02}, Section~E.2:
    Montgomery-to-Weierstrass coordinate shift $w_x = u + A/3$.
  \item[Algorithm]
    Computes $w_x = (1-y)^{-1} \cdot (1+y) + A/3 \bmod p$.
    Three operations: \fn{fe\_mul} (Montgomery $u$-coordinate),
    \fn{fe\_add} (shift by \fn{fe\_a\_inv\_3}), \fn{fe\_tobytes} (serialize).
    Pre-computed inverse $(1-y)^{-1}$ passed as parameter.
  \item[Constant-time]
    Yes.  Pure ref10 field arithmetic: \fn{fe\_mul}, \fn{fe\_add}, \fn{fe\_tobytes}.
    No branches on input values.
  \item[Dependency]
    Uses \fn{fe\_a\_inv\_3} constant ($A/3 \bmod p$, \href{\prTenThreeFourFive/src/crypto/crypto-ops-data.c\#L874}{\src{crypto-ops-data.c:874}}).
    Called by \href{\prTenThreeFourFive/src/crypto/crypto-ops.c\#L3950}{\fn{fe\_ed\_derivatives\_to\_wei\_x\_y}} (this PR).
  \item[Walkthrough]
    \src{fcmp-impl-audit-gsd/docs/pr10345-walkthrough.md}
\end{description}

\subsubsection*{\fn{fe\_ed\_derivatives\_to\_wei\_x\_y}}
\evidenceref{https://github.com/j-berman/monero/blob/a1f170e6e429b191acdb95b664fb9c73864679db/src/crypto/crypto-ops.c\#L3950}{PointToWeiXY.KnownAnswerVectors}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFourFive/src/crypto/crypto-ops.c\#L3950-L3963}{\src{crypto-ops.c:3950--3963}}
  \item[Signature]
    \fn{void fe\_ed\_derivatives\_to\_wei\_x\_y(unsigned char *wei\_x, unsigned char *wei\_y, const fe inv\_one\_minus\_y, const fe one\_plus\_y, const fe inv\_one\_minus\_y\_mul\_x)}
  \item[Spec]
    \href{https://www.ietf.org/archive/id/draft-ietf-lwig-curve-representations-02.pdf}{IETF draft-ietf-lwig-curve-representations-02}, Section~E.2:
    full Weierstrass $(w_x, w_y)$ from Edwards derivatives via Montgomery intermediate.
    $w_x = (1+y)/(1-y) + A/3$, \ $w_y = c \cdot (1+y) / ((1-y) \cdot x)$
    where $c = \sqrt{-(A+2)} \bmod p$.
  \item[Algorithm]
    Delegates $w_x$ to \fn{fe\_ed\_derivatives\_to\_wei\_x}.
    Computes $w_y$: two \fn{fe\_mul} (first $c \cdot (1+y)$, then result times
    $((1-y) \cdot x)^{-1}$), one \fn{fe\_tobytes}.
    Total: 3~\fn{fe\_mul}, 1~\fn{fe\_add}, 2~\fn{fe\_tobytes}.
  \item[Constant-time]
    Yes.  Same ref10 primitives as above; no data-dependent branches.
    Primary CT analysis target for Timecop annotation.
  \item[Dependency]
    Uses \fn{fe\_c} constant ($\sqrt{-(A+2)} \bmod p$,
    \href{\prTenThreeFourFive/src/crypto/crypto-ops-data.c\#L875}{\src{crypto-ops-data.c:875}}).
    Uses \fn{fe\_a\_inv\_3} via \fn{fe\_ed\_derivatives\_to\_wei\_x}.
    Called by \fn{ed\_derivatives\_to\_wei\_x\_y} (\href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L98}{\src{fcmp\_pp\_crypto.cpp:98}}).
  \item[Walkthrough]
    \src{fcmp-impl-audit-gsd/docs/pr10345-walkthrough.md}
\end{description}

\subsubsection*{\fn{point\_to\_ed\_derivatives}}
\evidenceref{https://github.com/j-berman/monero/blob/a1f170e6e429b191acdb95b664fb9c73864679db/src/fcmp_pp/fcmp_pp_crypto.cpp\#L69}{PointToWeiXY.Basepoint}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L69-L84}{\src{fcmp\_pp\_crypto.cpp:69--84}}
  \item[Signature]
    \fn{bool point\_to\_ed\_derivatives(const crypto::ec\_point \&pub, EdDerivatives \&ed\_derivatives)}
  \item[Spec]
    Decompresses Ed25519 point and computes the three intermediate field elements
    needed for Weierstrass conversion: $(1+y)$, $(1-y)$, $(1-y) \cdot x$.
  \item[Algorithm]
    Step~1: reject identity ($\fn{pub} = \fn{EC\_I}$, returns \fn{false}).
    Step~2: \fn{ge\_frombytes\_vartime} to decompress $(X, Y, Z\!=\!1, T)$.
    Step~3: \fn{fe\_add}/\fn{fe\_sub}/\fn{fe\_mul} to populate \fn{EdDerivatives}.
    No inversion performed --- deferred to batch inversion in caller.
  \item[Constant-time]
    Variable-time (early return on identity, \fn{ge\_frombytes\_vartime}).
    Acceptable: input is a public blockchain key.
  \item[Dependency]
    Output struct consumed by \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L86}{\fn{ed\_derivatives\_to\_wei\_x\_y}} (this PR)
    and by \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L155}{\fn{outputs\_to\_leaves}} (\prlink{10360}{outputs\_to\_leaves}) for batch processing.
  \item[Walkthrough]
    \src{fcmp-impl-audit-gsd/docs/pr10345-walkthrough.md}
\end{description}

\subsubsection*{\fn{ed\_derivatives\_to\_wei\_x\_y}}
\evidenceref{https://github.com/j-berman/monero/blob/a1f170e6e429b191acdb95b664fb9c73864679db/src/fcmp_pp/fcmp_pp_crypto.cpp\#L86}{EdDerivativesToWeiXY.CrossPRBatchInvert}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L86-L106}{\src{fcmp\_pp\_crypto.cpp:86--106}}
  \item[Signature]
    \fn{bool ed\_derivatives\_to\_wei\_x\_y(const EdDerivatives \&ed\_derivatives, crypto::ec\_coord \&wei\_x, crypto::ec\_coord \&wei\_y)}
  \item[Spec]
    Batch-inverts $(1-y)$ and $(1-y) \cdot x$, then computes full Weierstrass
    $(w_x, w_y)$ via \fn{fe\_ed\_derivatives\_to\_wei\_x\_y}.
  \item[Algorithm]
    Copies \fn{one\_minus\_y} and \fn{one\_minus\_y\_mul\_x} into batch array ($n = 2$).
    Calls \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\fn{fe\_batch\_invert}} (\prlink{10111}{batch inverse}) to get $[(1-y)^{-1}, ((1-y) \cdot x)^{-1}]$.
    Delegates to low-level \fn{fe\_ed\_derivatives\_to\_wei\_x\_y} for field arithmetic.
    Always returns \fn{true}.
  \item[Constant-time]
    The \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\fn{fe\_batch\_invert}} and \href{\prTenThreeFourFive/src/crypto/crypto-ops.c\#L3950}{\fn{fe\_ed\_derivatives\_to\_wei\_x\_y}} calls are
    constant-time for fixed $n$.  Heap allocation (\fn{make\_unique}) is implementation-defined
    but typically CT for fixed sizes.
  \item[Dependency]
    Requires \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\fn{fe\_batch\_invert}} (\prlink{10111}{batch inverse},
    \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\src{crypto-ops.c:332}}).
    Called by \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L108}{\fn{point\_to\_wei\_x\_y}} (this PR) and
    \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L155}{\fn{outputs\_to\_leaves}} (\prlink{10360}{outputs\_to\_leaves}).
  \item[Walkthrough]
    \src{fcmp-impl-audit-gsd/docs/pr10345-walkthrough.md}
\end{description}

\subsubsection*{\fn{point\_to\_wei\_x\_y}}
\evidenceref{https://github.com/j-berman/monero/blob/a1f170e6e429b191acdb95b664fb9c73864679db/src/fcmp_pp/fcmp_pp_crypto.cpp\#L108}{PointToWeiXY.OutputOnWeierstrass}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L108-L113}{\src{fcmp\_pp\_crypto.cpp:108--113}}
  \item[Signature]
    \fn{bool point\_to\_wei\_x\_y(const crypto::ec\_point \&pub, crypto::ec\_coord \&wei\_x, crypto::ec\_coord \&wei\_y)}
  \item[Spec]
    Full pipeline: compressed Ed25519 point to Weierstrass $(w_x, w_y)$.
    Composition of \fn{point\_to\_ed\_derivatives} and \fn{ed\_derivatives\_to\_wei\_x\_y}.
  \item[Algorithm]
    Step~1: \fn{point\_to\_ed\_derivatives} (decompress, reject identity, compute intermediates).
    Step~2: \fn{ed\_derivatives\_to\_wei\_x\_y} (batch invert, field arithmetic).
    Returns \fn{false} if identity or decompression fails.
  \item[Constant-time]
    Variable-time wrapper (early return).  Core field arithmetic is CT.
    Public-data context: no secret key material processed.
  \item[Dependency]
    Composes \fn{point\_to\_ed\_derivatives} and \fn{ed\_derivatives\_to\_wei\_x\_y} (this PR).
    Transitively depends on \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\fn{fe\_batch\_invert}} (\prlink{10111}{batch inverse}).
    Output feeds into FCMP++ Selene/Helios curve tree leaf construction (\prlink{10358}{output -> tuple}, \prlink{10360}{outputs\_to\_leaves}).
  \item[Walkthrough]
    \src{fcmp-impl-audit-gsd/docs/pr10345-walkthrough.md}
\end{description}

\subsubsection*{Hardcoded Constants}
\evidenceref{https://github.com/j-berman/monero/blob/a1f170e6e429b191acdb95b664fb9c73864679db/src/crypto/crypto-ops-data.c\#L874}{ConstantVerification.FeAInv3}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[\fn{fe\_a}]
    \href{\prTenThreeFourFive/src/crypto/crypto-ops-data.c\#L867}{\src{crypto-ops-data.c:867}}.
    $A = 486662$, the Montgomery coefficient for Curve25519.
    Single limb in ref10 representation.
  \item[\fn{fe\_a\_inv\_3}]
    \href{\prTenThreeFourFive/src/crypto/crypto-ops-data.c\#L874}{\src{crypto-ops-data.c:874}}.
    $A/3 \bmod p = 486662 \cdot 3^{-1} \bmod (2^{255} - 19)$.
    Independently verified: limb reconstruction matches $A \cdot \text{pow}(3, p\!-\!2, p) \bmod p$.
  \item[\fn{fe\_c}]
    \href{\prTenThreeFourFive/src/crypto/crypto-ops-data.c\#L875}{\src{crypto-ops-data.c:875}}.
    $c = \sqrt{-(A+2)} \bmod p$.  Verified: $c^2 \equiv -(A+2) \pmod{p}$.
    Square root computed via $(-(A+2))^{(p+3)/8} \cdot \sqrt{-1} \bmod p$
    (adjustment needed because $-(A+2)$ is not a QR of the principal root).
  \item[Cross-references]
    \href{\prTenThreeFourFive/src/crypto/crypto-ops-data.c\#L867}{\fn{fe\_a}} also used by Elligator~2 (\prlink{10338}{key image generator}).
    \fn{fe\_a\_inv\_3} and \fn{fe\_c} are specific to the Weierstrass conversion.
\end{description}

\paragraph{References.}
\begin{itemize}[nosep]
  \item \href{https://www.ietf.org/archive/id/draft-ietf-lwig-curve-representations-02.pdf}{IETF draft-ietf-lwig-curve-representations-02} --- Edwards-to-Weierstrass mapping (Section~E.2)
  \item \href{https://cr.yp.to/ecdh/curve25519-20060209.pdf}{Bernstein, Curve25519} --- Montgomery curve constants ($A = 486662$)
  \item \href{https://ed25519.cr.yp.to/ed25519-20110926.pdf}{Bernstein et al., Ed25519} --- field arithmetic and radix-$2^{25.5}$ representation
\end{itemize}

\clearpage

% ============================================================
\section{Audit 1b: Integrated Crypto}
% ============================================================

% ============================================================
% PR #10358: Output Pair Types and Visitors (enriched from fragment)
% ============================================================

\subsection{\prlink{10358}{FCMP++: output\_to\_pre\_leaf\_tuple}}

Branch \href{https://github.com/monero-project/monero/pull/10358}{\texttt{pr-10358}}, tip \href{https://github.com/j-berman/monero/commit/f9f16c7c607bb28152c9b0a1c6b753c20b3fa6be}{\texttt{f9f16c7}}.

\subsubsection*{\fn{output\_tuple\_from\_bytes}}
\evidenceref{https://github.com/j-berman/monero/blob/f9f16c7c607bb28152c9b0a1c6b753c20b3fa6be/src/fcmp_pp/fcmp_pp_types.cpp\#L39}{OutputTypesAdversarial.OutputTupleFromBytesMemcpy}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp\#L39-L52}{\src{fcmp\_pp\_types.cpp:39--52}}
  \item[Signature]
    \fn{OutputTuple output\_tuple\_from\_bytes(const crypto::ec\_point \&O, const crypto::ec\_point \&I, const crypto::ec\_point \&C)}
  \item[Spec]
    Integration glue -- no external cryptographic specification.
    Assembles three 32-byte compressed curve points $(O, I, C)$ into a 96-byte
    \fn{OutputTuple} struct via \fn{memcpy}.  Compile-time \fn{static\_assert}
    checks verify $|\fn{O}| = |\fn{I}| = |\fn{C}| = 32$.
  \item[Algorithm]
    Pure data copy: $\text{tuple}[0{:}31] \leftarrow O$, $\text{tuple}[32{:}63] \leftarrow I$,
    $\text{tuple}[64{:}95] \leftarrow C$.  No arithmetic, no validation.
  \item[CT status]
    Constant-time (\fn{memcpy} of fixed-size public data).
  \item[Downstream]
    Called by \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L112}{\fn{output\_to\_tuple}}
    (\href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L112}{\src{curve\_trees.cpp:112}})
    to construct leaf tuples for the FCMP++ Merkle tree.
\end{description}

\subsubsection*{\fn{output\_pubkey\_cref}}
\evidenceref{https://github.com/j-berman/monero/blob/f9f16c7c607bb28152c9b0a1c6b753c20b3fa6be/src/fcmp_pp/fcmp_pp_types.cpp\#L55}{OutputTypesAdversarial.LegacyTorsionCheckFalse}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp\#L55-L66}{\src{fcmp\_pp\_types.cpp:55--66}}
  \item[Signature]
    \fn{const crypto::public\_key \&output\_pubkey\_cref(const OutputPair \&output\_pair)}
  \item[Spec]
    Accessor -- extracts output public key $O$ from either \fn{LegacyOutputPair}
    or \fn{CarrotOutputPairV1} via \fn{std::visit} with exhaustive visitor.
    Both overloads return \fn{o.output\_pubkey}.
  \item[CT status]
    Constant-time (no secret-dependent branching; variant dispatch is on public type tag).
  \item[Downstream]
    Used by \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L68}{\fn{output\_to\_tuple}} for torsion-clearing and key-image-generator derivation.
\end{description}

\subsubsection*{\fn{commitment\_cref}}
\evidenceref{https://github.com/j-berman/monero/blob/f9f16c7c607bb28152c9b0a1c6b753c20b3fa6be/src/fcmp_pp/fcmp_pp_types.cpp\#L68}{OutputTypesAdversarial.LegacyTorsionCheckFalse}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp\#L68-L79}{\src{fcmp\_pp\_types.cpp:68--79}}
  \item[Signature]
    \fn{const crypto::ec\_point \&commitment\_cref(const OutputPair \&output\_pair)}
  \item[Spec]
    Accessor -- extracts commitment $C$ from either variant via exhaustive visitor.
    Note: commitment is typed as \fn{ec\_point} (not \fn{rct::key}) to avoid circular
    header dependency.  Both are 32-byte PODs.
  \item[CT status]
    Constant-time.
  \item[Downstream]
    Used by \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L88}{\fn{output\_to\_tuple}} for Weierstrass conversion of the commitment coordinate.
\end{description}

\subsubsection*{\fn{output\_checked\_for\_torsion}}
\evidenceref{https://github.com/j-berman/monero/blob/f9f16c7c607bb28152c9b0a1c6b753c20b3fa6be/src/fcmp_pp/fcmp_pp_types.cpp\#L81}{OutputTypesAdversarial.LegacyTorsionCheckFalse}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp\#L81-L92}{\src{fcmp\_pp\_types.cpp:81--92}}
  \item[Signature]
    \fn{bool output\_checked\_for\_torsion(const OutputPair \&output\_pair)}
  \item[Spec]
    Behavioral dispatch flag.  Returns \fn{true} for \fn{CarrotOutputPairV1}
    (torsion already cleared at construction), \fn{false} for \fn{LegacyOutputPair}
    (may have torsion, must apply \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L57}{\fn{get\_valid\_torsion\_cleared\_point}} from \prlink{10342}{torsion clearing}).
  \item[Algorithm]
    Exhaustive visitor on \fn{OutputPair} variant.  Carrot $\to$ \fn{true},
    Legacy $\to$ \fn{false}.
  \item[CT status]
    Constant-time (dispatch on public type tag).
  \item[Downstream]
    Controls whether \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L71}{\fn{output\_to\_tuple}}
    (\href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L71}{\src{curve\_trees.cpp:71}})
    invokes torsion clearing via \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L57}{\fn{get\_valid\_torsion\_cleared\_point}}.
    If wrong for Legacy: torsioned points enter tree.
    If wrong for Carrot: unnecessary clearing (wasteful but safe).
\end{description}

\subsubsection*{\fn{use\_biased\_hash\_to\_point}}
\evidenceref{https://github.com/j-berman/monero/blob/f9f16c7c607bb28152c9b0a1c6b753c20b3fa6be/src/fcmp_pp/fcmp_pp_types.cpp\#L94}{OutputTypesAdversarial.LegacyUseBiasedTrue}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp\#L94-L105}{\src{fcmp\_pp\_types.cpp:94--105}}
  \item[Signature]
    \fn{bool use\_biased\_hash\_to\_point(const OutputPair \&output\_pair)}
  \item[Spec]
    Behavioral dispatch flag.  Returns \fn{true} for \fn{LegacyOutputPair}
    (use original \fn{ge\_fromfe\_frombytes\_vartime} biased hash-to-point),
    \fn{false} for \fn{CarrotOutputPairV1} (use unbiased Elligator~2 / RFC~9380
    hash-to-curve).
  \item[Algorithm]
    Exhaustive visitor on \fn{OutputPair} variant.  Legacy $\to$ \fn{true},
    Carrot $\to$ \fn{false}.  Logical complement of \fn{output\_checked\_for\_torsion}.
  \item[CT status]
    Constant-time (dispatch on public type tag).
  \item[Downstream]
    Controls which hash-to-curve function \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L660}{\fn{derive\_key\_image\_generator}} uses.
    If wrong: key image generator $I$ is computed incorrectly, making outputs
    unspendable or enabling double-spends with mismatched key images.
\end{description}

\subsubsection*{Type hierarchy (header)}
\evidenceref{https://github.com/j-berman/monero/blob/f9f16c7c607bb28152c9b0a1c6b753c20b3fa6be/src/fcmp_pp/fcmp_pp_types.h\#L59}{OutputTypesAdversarial.OutputTupleFromBytesMemcpy}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.h\#L59-L95}{\src{fcmp\_pp\_types.h:59--95}}
  \item[Description]
    CRTP-based type hierarchy: \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.h\#L59}{\fn{OutputPairTemplate<T>}} holds $\{O, C\}$ as
    \fn{\{public\_key, ec\_point\}}.  Two derived types: \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.h\#L74}{\fn{LegacyOutputPair}}
    (may have torsion, biased H2P) and \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.h\#L77}{\fn{CarrotOutputPairV1}} (torsion-free,
    unbiased H2P).  \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.h\#L82}{\fn{OutputPair} = \fn{std::variant<Legacy, Carrot>}} provides
    compiler-enforced exhaustive dispatch.  \fn{static\_assert} checks enforce
    64-byte layout and no padding.
\end{description}

\subsubsection*{\fn{output\_to\_tuple} (from \href{https://github.com/monero-project/monero/pull/10358}{PR~\#10358} branch)}
\evidenceref{https://github.com/j-berman/monero/blob/f9f16c7c607bb28152c9b0a1c6b753c20b3fa6be/src/fcmp_pp/curve_trees.cpp\#L55}{OutputToTuple.LegacyValidPoint}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFiveEight/src/fcmp_pp/curve_trees.cpp\#L55-L113}{\src{curve\_trees.cpp:55--113}}
  \item[Signature]
    \fn{OutputTuple output\_to\_tuple(const OutputPair \&output\_pair)}
  \item[Spec]
    Converts a Monero output (one-time address $O$, commitment $C$) to a curve tree leaf
    triple $(O', I, C')$. Clears torsion, derives key image generator, rejects identity.
    See \href{https://raw.githubusercontent.com/kayabaNerve/fcmp-plus-plus-paper/refs/heads/develop/fcmp%2B%2B.pdf}{FCMP++ paper (Parker 2024)}
    for the curve tree leaf structure.
    Backward compatibility requirement: no historically valid Monero output may cause this to throw.
  \item[Integration note]
    In the mega commit (\ghlink{src/fcmp_pp/curve_trees.cpp\#L79-L147}{lines 79--147}),
    this function gains a second parameter \fn{bool use\_fast\_check}.
  \item[Call sites]
    \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L145}{\fn{output\_to\_pre\_leaf\_tuple}} (\href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L145}{\src{curve\_trees.cpp:145}}).
\end{description}

\paragraph{References.}
\begin{itemize}[nosep]
  \item \href{https://raw.githubusercontent.com/kayabaNerve/fcmp-plus-plus-paper/refs/heads/develop/fcmp%2B%2B.pdf}{FCMP++ paper (Parker 2024)} --- curve tree leaf structure
  \item \href{https://veridise.com/wp-content/uploads/2025/06/VAR_Monero_250407_fcmp___V3.pdf}{Veridise FCMP++ Audit Report (2025)} --- protocol-level audit
\end{itemize}

\clearpage

% ============================================================
% PR #10359: Rust FFI (enriched from fragment)
% ============================================================

\subsection{\prlink{10359}{FCMP++: Rust FFI selene\_scalar\_from\_bytes}}

Branch \href{https://github.com/monero-project/monero/pull/10359}{\texttt{pr-10359}}, tip \href{https://github.com/j-berman/monero/commit/b549d491f1cb38a635d6fd5a95918776a6d37958}{\texttt{b549d49}}.

Audit scope: C wrapper only; Rust internals covered by Veridise audit.

\subsubsection*{\fn{selene\_scalar\_from\_bytes} (C++ wrapper)}
\evidenceref{https://github.com/j-berman/monero/blob/b549d491f1cb38a635d6fd5a95918776a6d37958/src/fcmp_pp/tower_cycle.cpp\#L45}{SeleneScalarAdversarial.ZeroBytesInput}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFiveNine/src/fcmp_pp/tower_cycle.cpp\#L45-L51}{\src{tower\_cycle.cpp:45--51}}
  \item[Signature]
    \fn{SeleneScalar selene\_scalar\_from\_bytes(const crypto::ec\_coord \&bytes)}
  \item[Spec]
    FFI bridge -- no external cryptographic specification.  Passes a 32-byte
    little-endian field element (from \ghlink{src/crypto/crypto-ops.c\#L1079}{\fn{fe\_tobytes}}) across the C/Rust boundary
    to the helioselene crate's \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/src/lib.rs\#L31}{\fn{selene\_scalar\_from\_bytes}}.
    Maps $a \in \mathbb{F}_p$ (Ed25519) to $s \in \mathbb{F}_q$ (Selene base field).
  \item[Algorithm]
    (1)~Cast \fn{ec\_coord} to \fn{uint8\_t*} via \fn{to\_bytes}.
    (2)~Call Rust FFI function \fn{::selene\_scalar\_from\_bytes}.
    (3)~Check return code via \fn{CHECK\_FFI\_RES}; throw on $r \neq 0$.
    (4)~Return \fn{SeleneScalar} by value.
  \item[CT status]
    C wrapper is constant-time (no branching on input data; error check branches
    on return code only).  Rust-side CT status is Veridise scope.
  \item[FFI contract]
    See \texttt{pr10359-ffi-contract.md} for full contract specification including
    memory ownership, thread safety, error semantics, and assumptions.
    Key invariants: no heap across boundary, caller-allocated I/O, all non-zero
    return codes fatal on C side.
  \item[Audit scope]
    C wrapper only.  Rust internals in the helioselene crate are covered by the
    Veridise audit.  The FFI contract document defines the boundary obligations
    for both sides.
  \item[Downstream]
    Called by \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L280}{\fn{outputs\_to\_leaves}} (\prlink{10360}{outputs\_to\_leaves}) for every coordinate of every
    leaf tuple: six calls per output $(O_x, O_y, I_x, I_y, C_x, C_y)$.
    Single point of failure for all FCMP++ leaf construction.
\end{description}

\subsubsection*{\fn{SeleneScalar} (FFI type)}
\evidenceref{https://github.com/j-berman/monero/blob/b549d491f1cb38a635d6fd5a95918776a6d37958/src/fcmp_pp/fcmp_pp_rust/fcmp++.h\#L37}{SeleneScalarAdversarial.ZeroBytesInput}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/fcmp++.h\#L37-L39}{\src{fcmp++.h:37--39}}
  \item[Description]
    Opaque 32-byte struct: \fn{uintptr\_t \_0[32 / sizeof(uintptr\_t)]}.
    Machine-word-aligned to match Rust \fn{repr(C)} layout.
    On 64-bit: 4 $\times$ 8-byte words.  On 32-bit: 8 $\times$ 4-byte words.
    C side treats as opaque; never interprets individual bytes.
  \item[Rust counterpart]
    \fn{Field25519} in the \fn{helioselene} crate, aliased as \fn{SeleneScalar}
    in \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/src/lib.rs\#L3}{\src{lib.rs:3}}.
\end{description}

\subsubsection*{\fn{selene\_scalar\_from\_bytes} (Rust FFI)}
\evidenceref{https://github.com/j-berman/monero/blob/b549d491f1cb38a635d6fd5a95918776a6d37958/src/fcmp_pp/fcmp_pp_rust/src/lib.rs\#L31}{SeleneScalarAdversarial.ErrorCodePropagation}{REGRESSION}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/src/lib.rs\#L31}{\src{lib.rs:31}}
  \item[Generated by]
    \fn{ec\_elem\_from\_bytes!(selene\_scalar\_from\_bytes, SeleneScalar, Selene, read\_F)}
    (macro at \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/src/lib.rs\#L7-L29}{\src{lib.rs:7--29}}).
  \item[C header]
    \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/fcmp++.h\#L54}{\src{fcmp++.h:54}}: \\
    \fn{int selene\_scalar\_from\_bytes(const uint8\_t *selene\_scalar\_bytes, struct SeleneScalar *selene\_scalar\_out);}
\end{description}

\paragraph{References.}
\begin{itemize}[nosep]
  \item \href{https://crates.io/crates/helioselene}{helioselene crate} --- Rust implementation of Helios/Selene cycle
  \item \href{https://moneroresearch.info/index.php?action=attachments_ATTACHMENTS_CORE&method=downloadAttachment&id=271&resourceId=279&filename=776be5a7b6e6f22097a9491852ae2b731af49e16}{Helios/Selene Security Assessment (2024)}
  \item \href{https://raw.githubusercontent.com/kayabaNerve/fcmp-plus-plus-paper/refs/heads/develop/fcmp%2B%2B.pdf}{FCMP++ paper (Parker 2024)}
\end{itemize}

\clearpage

% ============================================================
% PR #10360: CurveTrees Class + outputs_to_leaves Pipeline (enriched from fragment)
% ============================================================

\subsection{\prlink{10360}{FCMP++: CurveTrees class + outputs\_to\_leaves}}

Branch \href{https://github.com/monero-project/monero/pull/10360}{\texttt{pr-10360}}, tip \href{https://github.com/j-berman/monero/commit/86a0aa46f59f53a1a96a4e239b9663e4ccd3e30d}{\texttt{86a0aa4}}.

\subsubsection*{Pipeline Overview}
\evidenceref{https://github.com/j-berman/monero/blob/86a0aa46f59f53a1a96a4e239b9663e4ccd3e30d/src/fcmp_pp/curve_trees.cpp\#L155}{E2EPipeline.LegacyOutputToEdDerivatives}{INDEPENDENT}

\href{https://github.com/monero-project/monero/pull/10360}{PR~\#10360} is the integration PR composing all Phase~1 and Phase~2 primitives into the
output-to-leaf pipeline for FCMP++ curve trees.  The pipeline takes blockchain outputs
$(O_{\text{raw}}, C_{\text{raw}})$ and produces Selene scalars $(w_x, w_y)$ for the
curve tree's leaf layer.

\medskip
\noindent\textbf{Call chain:}
\begin{enumerate}
  \item \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L58}{\fn{output\_to\_tuple}} (this PR): torsion clearing (\prlink{10342}{torsion clearing}) +
        key image derivation (\prlink{10338}{key image generator}) + type visitors (\prlink{10358}{output -> tuple})
  \item \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L119}{\fn{output\_tuple\_to\_pre\_leaf\_tuple}} (this PR):
        $3\times$ \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L69}{\fn{point\_to\_ed\_derivatives}} (\prlink{10345}{ed25519 -> Wei})
  \item \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L256}{\fn{outputs\_to\_leaves}} Step~3: \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\fn{fe\_batch\_invert}} (\prlink{10111}{batch inverse})
  \item \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L260}{\fn{outputs\_to\_leaves}} Step~4:
        \href{\prTenThreeFourFive/src/crypto/crypto-ops.c\#L3950}{\fn{fe\_ed\_derivatives\_to\_wei\_x\_y}} (\prlink{10345}{ed25519 -> Wei})
        $+$ \href{\prTenThreeFiveNine/src/fcmp_pp/tower_cycle.cpp\#L45}{\fn{selene\_scalar\_from\_bytes}} (\prlink{10359}{Rust FFI})
\end{enumerate}

\subsubsection*{\fn{output\_to\_tuple}}
\evidenceref{https://github.com/j-berman/monero/blob/86a0aa46f59f53a1a96a4e239b9663e4ccd3e30d/src/fcmp_pp/curve_trees.cpp\#L58}{OutputToTuple.LegacyTorsionedPoint}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L58-L117}{\src{curve\_trees.cpp:58--117}}
  \item[Signature]
    \fn{OutputTuple output\_to\_tuple(const OutputPair \&output\_pair)}
  \item[Spec]
    Composition of torsion clearing (FCMP++ paper, Section~5.1) and key image
    generator derivation (hash-to-point per RFC~9380 or biased Elligator~2).
  \item[Algorithm]
    Step~1: extract $(O_{\text{raw}}, C_{\text{raw}})$ via \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp\#L55}{\fn{output\_pubkey\_cref}},
    \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp\#L68}{\fn{commitment\_cref}} (\prlink{10358}{output -> tuple}).
    Step~2: if Legacy, clear torsion via \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L57}{\fn{get\_valid\_torsion\_cleared\_point}}
    (\prlink{10342}{torsion clearing}); if Carrot, skip.
    Step~3: reject identity ($O = \mathcal{O}$ or $C = \mathcal{O}$).
    Step~4: derive $I = \text{HashToPoint}(O_{\text{raw}})$ via
    \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L660}{\fn{derive\_key\_image\_generator}} (\prlink{10338}{key image generator}) using \emph{original}
    pubkey, not torsion-cleared $O$.
    Step~5: serialize $(O, I, C)$ via \href{\prTenThreeFiveEight/src/fcmp_pp/fcmp_pp_types.cpp\#L39}{\fn{output\_tuple\_from\_bytes}} (\prlink{10358}{output -> tuple}).
  \item[Critical note]
    $I$ is derived from $O_{\text{raw}}$, not $O$.  If derived from the
    torsion-cleared $O$, a torsioned output could yield two distinct key images
    (pre-fork vs.\ post-fork), enabling double-spend.
  \item[Constant-time]
    Variable-time.  Branches on output type (Legacy/Carrot) and torsion status.
    All inputs are public blockchain data.
  \item[Dependency]
    Calls \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L57}{\fn{get\_valid\_torsion\_cleared\_point}} (\prlink{10342}{torsion clearing}),
    \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L660}{\fn{derive\_key\_image\_generator}} (\prlink{10338}{key image generator}),
    type visitors (\prlink{10358}{output -> tuple}).
  \item[Walkthrough]
    \src{fcmp-impl-audit-gsd/docs/pr10360-walkthrough.md}
\end{description}

\subsubsection*{\fn{output\_tuple\_to\_pre\_leaf\_tuple}}
\evidenceref{https://github.com/j-berman/monero/blob/86a0aa46f59f53a1a96a4e239b9663e4ccd3e30d/src/fcmp_pp/curve_trees.cpp\#L119}{PointToEdDerivatives.EdDerivativesCorrectness}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L119-L143}{\src{curve\_trees.cpp:119--143}}
  \item[Signature]
    \fn{static PreLeafTuple output\_tuple\_to\_pre\_leaf\_tuple(const OutputTuple \&o)}
  \item[Spec]
    Edwards derivative extraction: for each point $P \in \{O, I, C\}$,
    decompress and compute $(1+y_P, 1-y_P, (1-y_P) \cdot x_P)$.
  \item[Algorithm]
    Calls \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L69}{\fn{point\_to\_ed\_derivatives}} (\prlink{10345}{ed25519 -> Wei}) three times, once per point.
    Rejects if any call fails (identity point or decompression failure).
    Returns \fn{PreLeafTuple} containing three \fn{EdDerivatives} structs
    (9 field elements total).
    No inversion performed---deferred to batch step in \fn{outputs\_to\_leaves}.
  \item[Constant-time]
    Variable-time (delegates to \fn{ge\_frombytes\_vartime}).
    Public-data context.
  \item[Dependency]
    Calls \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L69}{\fn{point\_to\_ed\_derivatives}} (\prlink{10345}{ed25519 -> Wei},
    \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L69-L84}{\src{fcmp\_pp\_crypto.cpp:69--84}}).
  \item[Walkthrough]
    \src{fcmp-impl-audit-gsd/docs/pr10360-walkthrough.md}
\end{description}

\subsubsection*{\fn{output\_to\_pre\_leaf\_tuple}}
\evidenceref{https://github.com/j-berman/monero/blob/86a0aa46f59f53a1a96a4e239b9663e4ccd3e30d/src/fcmp_pp/curve_trees.cpp\#L145}{E2EPipeline.LegacyOutputToEdDerivatives}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L145-L149}{\src{curve\_trees.cpp:145--149}}
  \item[Signature]
    \fn{static PreLeafTuple output\_to\_pre\_leaf\_tuple(const OutputPair \&output\_pair)}
  \item[Spec]
    Composition: \fn{output\_to\_tuple} $\circ$ \fn{output\_tuple\_to\_pre\_leaf\_tuple}.
  \item[Algorithm]
    Calls \fn{output\_to\_tuple}, then \fn{output\_tuple\_to\_pre\_leaf\_tuple}.
    Exceptions from either propagate to caller.
  \item[Walkthrough]
    \src{fcmp-impl-audit-gsd/docs/pr10360-walkthrough.md}
\end{description}

\subsubsection*{\fn{outputs\_to\_leaves} (5-step pipeline)}
\evidenceref{https://github.com/j-berman/monero/blob/86a0aa46f59f53a1a96a4e239b9663e4ccd3e30d/src/fcmp_pp/curve_trees.cpp\#L155}{E2EPipeline.LegacyOutputToEdDerivatives}{INDEPENDENT}

\begin{description}[style=nextline,leftmargin=2em]
  \item[Source]
    \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L155-L261}{\src{curve\_trees.cpp:155--261}}
  \item[Signature]
    \fn{template<C1, C2> void CurveTrees<C1,C2>::outputs\_to\_leaves(\ldots)}
  \item[Spec]
    Full output-to-leaf pipeline for FCMP++ curve trees.  Converts $N$
    blockchain outputs to Selene scalars for tree insertion via batch
    Edwards-to-Weierstrass conversion.
  \item[Algorithm]
    \textbf{Step~1} (lines~175--215): Multithreaded \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L145}{\fn{output\_to\_pre\_leaf\_tuple}}
    across $N$ outputs.  Invalid outputs caught and marked \fn{Boolean::False}.

    \textbf{Step~2} (lines~218--252): Collect Edwards derivatives into batch arrays.
    \fn{fe\_batch}$[6N_v]$: interleaved $[(1\!-\!y), (1\!-\!y)x]$ per point,
    3 points per output.
    \fn{one\_plus\_y\_vec}$[3N_v]$: one $(1\!+\!y)$ per point.

    \textbf{Step~3} (line~256): Single call to \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\fn{fe\_batch\_invert}}
    (\prlink{10111}{batch inverse}, Montgomery's trick) inverts all $6N_v$ field elements.
    Cost: $O(1)$ inversions $+ O(N)$ multiplications.

    \textbf{Step~4} (lines~260--291): Multithreaded Weierstrass conversion via
    \href{\prTenThreeFourFive/src/crypto/crypto-ops.c\#L3950}{\fn{fe\_ed\_derivatives\_to\_wei\_x\_y}} (\prlink{10345}{ed25519 -> Wei}) using batch inversion
    results.  Each $(w_x, w_y)$ converted to \href{\prTenThreeFiveNine/src/fcmp_pp/fcmp_pp_rust/fcmp++.h\#L37}{\fn{SeleneScalar}} via
    \href{\prTenThreeFiveNine/src/fcmp_pp/tower_cycle.cpp\#L45}{\fn{selene\_scalar\_from\_bytes}} (\prlink{10359}{Rust FFI}).
    Index arithmetic: for point $j$, \fn{point\_idx} $= 2j$ indexes both
    \fn{batch\_inv\_res} and \fn{flattened\_leaves\_out}.

    \textbf{Step~5} (lines~294--302): Filter valid outputs into output vector.
  \item[Thread safety]
    Uses \fn{enum Boolean : uint8\_t} instead of \fn{std::vector<bool>} to
    avoid bit-packing data races.  Each thread writes to non-overlapping array
    ranges.  \fn{waiter.wait()} barriers between pipeline stages.
  \item[Constant-time]
    Step~3 (\href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\fn{fe\_batch\_invert}}) and the field arithmetic in Step~4 are
    constant-time for fixed $N_v$.  Steps~1, 2, 5 are variable-time
    (data-dependent branching on validity).  All inputs are public.
  \item[Dependency]
    Composes: \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\fn{fe\_batch\_invert}} (\prlink{10111}{batch inverse}),
    \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L69}{\fn{point\_to\_ed\_derivatives}} (\prlink{10345}{ed25519 -> Wei}),
    \href{\prTenThreeFourFive/src/crypto/crypto-ops.c\#L3950}{\fn{fe\_ed\_derivatives\_to\_wei\_x\_y}} (\prlink{10345}{ed25519 -> Wei}),
    \href{\prTenThreeFiveNine/src/fcmp_pp/tower_cycle.cpp\#L45}{\fn{selene\_scalar\_from\_bytes}} (\prlink{10359}{Rust FFI}),
    \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L57}{\fn{get\_valid\_torsion\_cleared\_point}} (\prlink{10342}{torsion clearing}),
    \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L660}{\fn{derive\_key\_image\_generator}} (\prlink{10338}{key image generator}),
    type visitors (\prlink{10358}{output -> tuple}).
  \item[\free{Naming inconsistency}]
    The \href{https://github.com/seraphis-migration/monero/issues/294}{audit request} uses the name \fn{outputs\_to\_leaves}, which matches the PR branch code.
    The mega commit renames it to \ghlink{src/fcmp_pp/curve_trees.cpp\#L1511}{\fn{set\_valid\_leaves}} and adds a \fn{bool use\_fast\_torsion\_check}
    parameter. \textbf{Recommend raising with the PR author to confirm canonical naming before audit publication.}
  \item[Walkthrough]
    \src{fcmp-impl-audit-gsd/docs/pr10360-walkthrough.md}
\end{description}

\subsubsection*{Batch Array Layout}
\evidenceref{https://github.com/j-berman/monero/blob/86a0aa46f59f53a1a96a4e239b9663e4ccd3e30d/src/fcmp_pp/curve_trees.cpp\#L218}{E2EPipeline.LegacyOutputToEdDerivatives}{REGRESSION}

For $N_v$ valid outputs, 3 points each ($O$, $I$, $C$):

\begin{itemize}
  \item \fn{fe\_batch}$[6N_v]$:
    $[O_0.(1\!-\!y),\; O_0.(1\!-\!y)x,\;
      I_0.(1\!-\!y),\; I_0.(1\!-\!y)x,\;
      C_0.(1\!-\!y),\; C_0.(1\!-\!y)x,\;
      O_1.\ldots]$
  \item \fn{one\_plus\_y\_vec}$[3N_v]$:
    $[O_0.(1\!+\!y),\; I_0.(1\!+\!y),\; C_0.(1\!+\!y),\;
      O_1.(1\!+\!y),\; \ldots]$
  \item \fn{batch\_inv\_res}$[6N_v]$: output of \fn{fe\_batch\_invert}.
    For point $j$: $\text{res}[2j] = (1\!-\!y_j)^{-1}$,
    $\text{res}[2j+1] = ((1\!-\!y_j) \cdot x_j)^{-1}$.
  \item Step~4 index: $\fn{point\_idx} = 2j$ indexes both
    \fn{batch\_inv\_res} (read) and \fn{flattened\_leaves\_out} (write).
\end{itemize}

\paragraph{References.}
\begin{itemize}[nosep]
  \item \href{https://raw.githubusercontent.com/kayabaNerve/fcmp-plus-plus-paper/refs/heads/develop/fcmp%2B%2B.pdf}{FCMP++ paper (Parker 2024)} --- curve tree construction
  \item \href{https://veridise.com/wp-content/uploads/2025/06/VAR_Monero_250407_fcmp___V3.pdf}{Veridise FCMP++ Audit Report (2025)} --- protocol-level audit
  \item \href{https://www.ietf.org/archive/id/draft-ietf-lwig-curve-representations-02.pdf}{IETF draft-ietf-lwig-curve-representations-02} --- Edwards-to-Weierstrass mapping
  \item \href{https://moneroresearch.info/index.php?action=attachments_ATTACHMENTS_CORE&method=downloadAttachment&id=271&resourceId=279&filename=776be5a7b6e6f22097a9491852ae2b731af49e16}{Helios/Selene Security Assessment (2024)}
  \item \href{https://arxiv.org/abs/math/0208038}{Montgomery (CT-RSA 2003)} --- batch inversion trick
  \item \href{https://www.rfc-editor.org/rfc/rfc9380}{RFC~9380} --- hash-to-curve
\end{itemize}

\clearpage

% ============================================================
\section{Call-Site Chains}
% ============================================================

How the 1b functions call back into 1a primitives:

\begin{itemize}[nosep,leftmargin=1.5em]
  \item \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L155}{\fn{outputs\_to\_leaves}} (\prlink{10360}{outputs\_to\_leaves})
  \begin{itemize}[nosep,leftmargin=1.5em]
    \item \href{\prTenThreeFiveEight/src/fcmp_pp/curve_trees.cpp\#L142}{\fn{output\_to\_pre\_leaf\_tuple}} (\prlink{10358}{output -> tuple})
    \begin{itemize}[nosep,leftmargin=1.5em]
      \item \href{\prTenThreeFiveEight/src/fcmp_pp/curve_trees.cpp\#L55}{\fn{output\_to\_tuple}} (\prlink{10358}{output -> tuple})
      \begin{itemize}[nosep,leftmargin=1.5em]
        \item \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L57}{\fn{get\_valid\_torsion\_cleared\_point}} (\prlink{10342}{Torsion clearing})
        \begin{itemize}[nosep,leftmargin=1.5em]
          \item \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L34}{\fn{mul8\_is\_identity}} (\prlink{10342}{Torsion clearing})
          \item \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L44}{\fn{clear\_torsion}} (\prlink{10342}{Torsion clearing})
        \end{itemize}
        \item \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L660}{\fn{derive\_key\_image\_generator}} (\prlink{10338}{Unbiased key image generator})
        \begin{itemize}[nosep,leftmargin=1.5em]
          \item \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L622}{\fn{unbiased\_hash\_to\_ec}} (\prlink{10338}{Unbiased key image generator})
          \begin{itemize}[nosep,leftmargin=1.5em]
            \item \ghlink{src/crypto/blake2b.c}{\fn{blake2b}}
            \item \ghlink{src/crypto/crypto-ops.c\#L2367}{\fn{ge\_fromfe\_frombytes\_vartime}}
          \end{itemize}
        \end{itemize}
      \end{itemize}
      \item \href{\prTenThreeFiveEight/src/fcmp_pp/curve_trees.cpp\#L117}{\fn{output\_tuple\_to\_pre\_leaf\_tuple}} (\prlink{10358}{output -> tuple})
      \begin{itemize}[nosep,leftmargin=1.5em]
        \item \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L69}{\fn{point\_to\_ed\_derivatives}} (\prlink{10345}{ed25519 -> Wei})
      \end{itemize}
    \end{itemize}
    \item \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\fn{fe\_batch\_invert}} (\prlink{10111}{Batch inverse})
    \item \href{\prTenThreeFourFive/src/crypto/crypto-ops.c\#L3950}{\fn{fe\_ed\_derivatives\_to\_wei\_x\_y}} (\prlink{10345}{ed25519 -> Wei})
    \begin{itemize}[nosep,leftmargin=1.5em]
      \item \href{\prTenThreeFourFive/src/crypto/crypto-ops.c\#L3937}{\fn{fe\_ed\_derivatives\_to\_wei\_x}} (\prlink{10345}{ed25519 -> Wei})
    \end{itemize}
    \item \href{\prTenThreeFiveNine/src/fcmp_pp/tower_cycle.cpp\#L45}{\fn{selene\_scalar\_from\_bytes}} (\prlink{10359}{Rust FFI})
    \begin{itemize}[nosep,leftmargin=1.5em]
      \item \fn{<Selene>::read\_F} (Rust)
    \end{itemize}
  \end{itemize}
\end{itemize}

\medskip

The individual-output path (via \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L86}{\fn{ed\_derivatives\_to\_wei\_x\_y}} rather than the batched path):

\begin{itemize}[nosep,leftmargin=1.5em]
  \item \ghlink{src/fcmp_pp/curve_trees.cpp\#L615}{\fn{pre\_leaf\_tuple\_to\_leaf\_tuple}}
  \begin{itemize}[nosep,leftmargin=1.5em]
    \item \href{\prTenThreeFourFive/src/fcmp_pp/fcmp_pp_crypto.cpp\#L86}{\fn{ed\_derivatives\_to\_wei\_x\_y}} (\prlink{10345}{ed25519 -> Wei})
    \begin{itemize}[nosep,leftmargin=1.5em]
      \item \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\fn{fe\_batch\_invert}} (\prlink{10111}{Batch inverse}, $n=2$)
      \item \href{\prTenThreeFourFive/src/crypto/crypto-ops.c\#L3950}{\fn{fe\_ed\_derivatives\_to\_wei\_x\_y}} (\prlink{10345}{ed25519 -> Wei})
    \end{itemize}
    \item \href{\prTenThreeFiveNine/src/fcmp_pp/tower_cycle.cpp\#L45}{\fn{selene\_scalar\_from\_bytes}} (\prlink{10359}{Rust FFI})
  \end{itemize}
\end{itemize}

% ============================================================
\section{Recommended Review Order}
% ============================================================

\begin{enumerate}
  \item \textbf{1a PRs} (reviewable in any order -- each is self-contained):
    \begin{itemize}[nosep]
      \item \prlink{10108}{6x faster zero commit} -- \href{\prTenOneOEight/src/ringct/rctOps.cpp\#L349}{\fn{zeroCommitVartime}} (independent, not in the cherry-pick chain)
      \item \prlink{10111}{Batch inverse} -- \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L332}{\fn{fe\_batch\_invert}}, \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L317}{\fn{fe\_equals}}, \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L1383}{\fn{fe\_frombytes\_vartime}}
      \item \prlink{10135}{fe\_reduce\_vartime} -- \href{\prTenOneThreeFive/src/crypto/crypto-ops.c\#L3907}{\fn{fe\_reduce\_vartime}} (depends on \href{\prTenOneOneOne/src/crypto/crypto-ops.c\#L1383}{\fn{fe\_frombytes\_vartime}})
      \item \prlink{10338}{Unbiased key image generator} -- \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L622}{\fn{unbiased\_hash\_to\_ec}}, \href{\prTenThreeThreeEight/src/crypto/crypto.cpp\#L660}{\fn{derive\_key\_image\_generator}}
      \item \prlink{10342}{Torsion clearing} -- \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L44}{\fn{clear\_torsion}}, \href{\prTenThreeFourTwo/src/fcmp_pp/fcmp_pp_crypto.cpp\#L34}{\fn{mul8\_is\_identity}}
      \item \prlink{9828}{Ed25519 -> X25519} -- \href{\prNineEightTwoEight/src/crypto/crypto-ops.c\#L3853}{\fn{ge\_p3\_to\_x25519}}, \href{\prNineEightTwoEight/src/crypto/crypto-ops.c\#L3858}{\fn{edwards\_bytes\_to\_x25519\_vartime}} (independent)
    \end{itemize}

  \item \textbf{\prlink{10345}{ed25519 -> Wei conversion}} -- Ed25519 $\to$ Weierstrass conversion.
    Depends on \prlink{10342}{Torsion clearing} + \prlink{10111}{Batch inverse} + \prlink{10135}{fe\_reduce\_vartime}.

  \item \textbf{1b PRs} in order:
    \begin{itemize}[nosep]
      \item \prlink{10358}{output -> tuple} -- \href{\prTenThreeFiveEight/src/fcmp_pp/curve_trees.cpp\#L55}{\fn{output\_to\_tuple}} (calls \prlink{10342}{torsion clearing} + \prlink{10338}{key image generator})
      \item \prlink{10359}{Rust FFI} -- \href{\prTenThreeFiveNine/src/fcmp_pp/tower_cycle.cpp\#L45}{\fn{selene\_scalar\_from\_bytes}} (FFI layer)
      \item \prlink{10360}{outputs\_to\_leaves} -- \href{\prTenThreeSixZero/src/fcmp_pp/curve_trees.cpp\#L155}{\fn{outputs\_to\_leaves}} (integration, calls everything)
    \end{itemize}
\end{enumerate}

\end{document}
''';
