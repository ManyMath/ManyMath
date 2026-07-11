/// Source of “FROSTLASS: Thresholdized Linkable Ring Signatures”, from `papers/FROSTLASS Thresholdization and Audit of Implementation/IACRSubmission.tex`.
const frostlassThresholdizationSource = r'''

\documentclass[runningheads]{llncs}
\usepackage[T1]{fontenc}
% \documentclass[12pt,a4paper]{article}
\usepackage{graphicx} 
\usepackage{amsmath,amsfonts,amssymb,amsthm}
\usepackage{enumerate}
\usepackage[hidelinks]{hyperref}
\usepackage[dvipsnames]{xcolor} 
\usepackage{cleveref}
\usepackage{aliascnt}
\usepackage{multicol}
\usepackage{tikz-cd}
\usepackage{titling}

\renewcommand{\thefootnote}{\fnsymbol{footnote}}

\theoremstyle{definition}

% \newtheorem{theorem}{Theorem}[section]
\newcommand{\theoremqed}{\hfill \qedsymbol}

% \newaliascnt{lemma}{theorem}
% \newtheorem{lemma}[lemma]{Lemma}
% \aliascntresetthe{lemma}
\crefname{lemma}{Lemma}{Lemmas}

\newaliascnt{cor}{theorem}
\newtheorem{cor}[cor]{Corollary}
\aliascntresetthe{cor}
\crefname{cor}{Corollary}{Corollaries}
\AtEndEnvironment{lemma}{\theoremqed}

% \newaliascnt{definition}{theorem}
% \newtheorem{definition}[definition]{Definition}
% \aliascntresetthe{definition}
\crefname{definition}{Definition}{Definitions}

% \newaliascnt{example}{theorem}
% \newtheorem{example}[example]{Example}
% \aliascntresetthe{example}
\crefname{example}{Example}{Examples}

% \newaliascnt{remark}{theorem}
% \newtheorem{remark}[remark]{Remark}
% \aliascntresetthe{remark}
\crefname{remark}{Remark}{Remarks}


\newcommand{\N}{\bbn}
\newcommand{\R}{\mathbb{R}}
\newcommand{\G}{\mathbb{G}}
\newcommand{\sk}{\texttt{sk}}
\newcommand{\sn}{\texttt{sn}}
\newcommand{\pk}{\texttt{pk}}
\newcommand{\vk}{\texttt{vk}}
\newcommand{\pn}{\texttt{pn}}
\newcommand{\lt}{\texttt{lt}}
\newcommand{\tlt}{\texttt{tlt}}
\newcommand{\sck}{\texttt{sck}}
\newcommand{\pck}{\texttt{pck}}
\newcommand{\tvk}{\texttt{tvk}}
\newcommand{\ring}{\texttt{ring}}
\newcommand{\SK}{\underline{\texttt{sk}}}
\newcommand{\VK}{\underline{\texttt{vk}}}
\newcommand{\TVK}{\underline{\texttt{tvk}}}
\newcommand{\LT}{\underline{\texttt{lt}}}
\newcommand{\dst}{\texttt{dst}}
\newcommand{\ch}{\texttt{ch}}
\newcommand{\resp}{\texttt{resp}}
\newcommand{\sig}{\texttt{sig}}
\newcommand{\psig}{\texttt{psig}}
\newcommand{\psigs}{\underline{\texttt{psig}}}
\newcommand{\seed}{\texttt{seed}}
\newcommand{\com}{\texttt{com}}
\newcommand{\bitstrings}{\left\{0,1\right\}^*}
\newcommand{\Zq}{\mathbb{Z}_q}
\newcommand{\bbn}{\mathbb{N}}
\newcommand{\secpar}{\lambda}
\newcommand{\rng}{F_{\texttt{PRNG}}}
\newcommand{\params}{\texttt{pars}}
\newcommand{\msg}{\texttt{msg}}
\newcommand{\setup}{\texttt{PGen}}
\newcommand{\setupI}{(\secpar)}
\newcommand{\setupO}{\params_\secpar}
\newcommand{\setupIO}{\setup\setupI\to\setupO}
\newcommand{\keygen}{\texttt{KGen}}
\newcommand{\keygenI}{(\setupO,n,r)}
\newcommand{\keygenIshort}{(n,r)}
\newcommand{\keygenO}{(\tvk,\VK,\SK)}
\newcommand{\keygenObase}{(\tvk, \VK, \SK)}
\newcommand{\keygenIO}{\keygen\keygenI\to\keygenO}
\newcommand{\keygenIObase}{\keygen\keygenI\to\keygenObase \in \mathcal{TVK} \times \mathcal{VK}^n \times \mathcal{SK}^n}
\newcommand{\preproc}{\texttt{PreProc}}
\newcommand{\preprocI}{(\setupO,\msg,\ring,\VK,\LT,\SK)}
\newcommand{\preprocO}{\com}
\newcommand{\preprocIO}{\preproc\preprocI\to\preprocO}
\newcommand{\sign}{\texttt{Sign}}
\newcommand{\aux}{\texttt{aux}}
\newcommand{\signI}{(\setupO,\msg,\ring,\VK,\LT,\sk)}
\newcommand{\signIbase}{(\setupO,\msg,\ring,\VK,\sk)}
\newcommand{\signO}{\psig}
\newcommand{\signIO}{\sign\signI\to\signO}
\newcommand{\signIObase}{\sign\signIbase\to\signO}
\newcommand{\combine}{\texttt{Combine}}
\newcommand{\PSIG}{\underline{\psig}}
\newcommand{\combineI}{(\setupO,\msg,\ring,\VK,\LT,\PSIG)}
\newcommand{\combineIbase}{(\setupO,\msg,\ring,\VK,\PSIG)}
\newcommand{\combineO}{\sig}
\newcommand{\combineIO}{\combine\combineI\to\combineO}
\newcommand{\combineIObase}{\combine\combineIbase\to\combineO}
\newcommand{\verify}{\texttt{Vf}}
\newcommand{\verifyI}{(\setupO,\msg,\ring,\sig)}
\newcommand{\verifyO}{b}
\newcommand{\verifyIO}{\verify\verifyI\to\verifyO}
\newcommand{\verifyIObase}{\verify\verifyI\to\verifyO}
\newcommand{\link}{\texttt{Link}}
\newcommand{\linkI}{(\setupO,\sig,\sig^\prime)}
\newcommand{\linkO}{\verifyO}
\newcommand{\linkIO}{\link\linkI\to\linkO}
\newcommand{\linkIObase}{\link\linkI\to\linkO}
\newcommand{\verifyshare}{\texttt{VfSh}}
\newcommand{\verifyshareI}{(\setupO,\msg,\ring,\VK,\psig)}
\newcommand{\verifyshareO}{\verifyO}
\newcommand{\verifyshareIO}{\verifyshare\verifyshareI\to\verifyshareO}
 \newcommand{\verifyshareIObase}{\verifyshare\verifyshareI\to\verifyshareO}
\newcommand{\chk}{\texttt{chk}}
\newcommand{\polysecpar}{O(\text{poly}(\secpar))}
\newcommand{\negl}{\text{negl}(\secpar)}
\newcommand{\FROST}{\texttt{FROST}}
\newcommand{\linkingtag}{\mathfrak{T}}
\newcommand{\sample}{\overset{\$}{\leftarrow}}
\newcommand{\fork}{\texttt{Fork}}
\newcommand{\corruptionOracle}{\mathcal{O}_{\texttt{corrupt}}}
\newcommand{\signingOracle}{\mathcal{O}_{\sign}}
\newcommand{\keyOracle}{\mathcal{O}_{\texttt{key}}}
\newcommand{\challengeKeySet}{\mathcal{L}_{\texttt{key}}}
\newcommand{\corruptedTotalKeys}{\mathcal{L}_{\texttt{corrupt}}^{\texttt{tot}}}
\newcommand{\corruptedKeyShareSet}{\mathcal{L}_{\texttt{corrupt}}^{\texttt{sh}}}
\newcommand{\corruptedKeySet}{\mathcal{L}_{\texttt{corrupt}}}
\newcommand{\signaturequery}{(\texttt{dst}_{j} \mid \mid \ring \mid \mid \tlt \mid \mid \underline{\widehat{Y}} \mid \mid \mathfrak{W} \mid \mid \underline{W} \mid \mid \underline{\mu} \mid \mid L_{j} \mid \mid R_{j} \mid \mid \msg)}
\newcommand{\signaturequerystar}{(\texttt{dst}_{j^*} \mid \mid \ring \mid \mid \tlt \mid \mid \underline{\widehat{Y}} \mid \mid \mathfrak{W} \mid \mid \underline{W} \mid \mid \underline{\mu} \mid \mid L_{j^*} \mid \mid R_{j^*} \mid \mid \msg)}

% \newcommand{\subtitle}[1]{%
%   \posttitle{%
%     \par\end{center}
%     \begin{center}\Large#1\end{center}
%     \vskip0.5em}%
% }


% Used to format table in Rosetta Stone
\usepackage{booktabs,array}
\newcommand{\PreserveBackslash}[1]{\let\temp=\\#1\let\\=\temp}
\newcolumntype{C}[1]{>{\PreserveBackslash\centering}p{#1}}
\newcolumntype{R}[1]{>{\PreserveBackslash\raggedleft}p{#1}}
\newcolumntype{L}[1]{>{\PreserveBackslash\raggedright}p{#1}}


% Used to format the pseudocode blocks
\usepackage{caption,subcaption}
\newcommand{\Fp}{\mathbb{F}_p}
\newcommand{\rar}{\rightarrow}
\newcommand{\lar}{\leftarrow}
\newcommand{\lsamp}{\xleftarrow{\$}}


% Adds the oracle and game environments
\DeclareCaptionType[fileext=los,placement={!ht}]{oracle}
\DeclareCaptionType[fileext=los,placement={!ht}]{game}




\usepackage{lmodern}                     % Improved font rendering
\usepackage{geometry}                    % Page geometry
% \geometry{margin=1in}                    % Set margins to your preference
\usepackage{enumitem}                    % Better control of list environments
\usepackage{makeidx}                     % For creating an index
\makeindex                               % Initialize index creation
\usepackage[toc, acronym]{glossaries}    % Glossaries and acronyms 
\usepackage{mdframed}                    % For framed boxes
\usepackage{tikz}
\usetikzlibrary{arrows.meta, positioning}

% Added this to allow for subsubsubsections
\usepackage{titlesec}


\newcounter{subsubsubsection}[subsubsection]
\renewcommand{\thesubsubsubsection}{\thesubsubsection.\arabic{subsubsubsection}}  % Number format

% Define the subsubsubsection command
\newcommand{\subsubsubsection}[1]{%
  \refstepcounter{subsubsubsection}  % Increment the counter
  \paragraph*{\thesubsubsubsection\ #1} % Format the section title
}


% -------------------- Glossary Entries --------------------%

    \newglossaryentry{monero-wallet (v0.1.0)}{
        name={\protect\texttt{monero-wallet (v0.1.0)}},
        description={A standard library crate, with the corresponding entry point at  \path{/wallet/src/lib.rs}. Handles all wallet functionality}
    }

    \newglossaryentry{monero-simple-request-rpc (v0.1.0)}{
        name={\protect\texttt{monero-simple-request-rpc (v0.1.0)}},
        description={A standard library crate, with the corresponding entry point at  \path{/rpc/simple-request/src/lib.rs}. Default RPC to avoid external dependences, e.g. reqwest}
    }
    
    \newglossaryentry{monero-rpc (v0.1.0)}{
        name={\protect\texttt{monero-rpc (v0.1.0)}},
        description={A standard library crate, with the corresponding entry point at \path{/rpc/src/lib.rs}, employing no file or directory modules. Handles RPC calls for interacting on the Monero network.}
    }

    \newglossaryentry{monero-serai (v0.1.4-alpha)}{
        name={\protect\texttt{monero-serai (v0.1.4-alpha)}},
        description={A standard library crate, with the corresponding entry point at \path{/src/lib.rs}. This is the overall transaction library.}
    }

    \newglossaryentry{monero-address (v0.1.0)}{
        name={\protect\texttt{monero-address (v0.1.0)}},
        description={A standard library crate, with the corresponding entry point at \path{/wallet/address/src/lib.rs}. Handles Monero addresses.}
    }

    \newglossaryentry{monero-borromean (v0.1.0)}{
        name={\protect\texttt{monero-borromean (v0.1.0)}},
        description={A standard library crate, with the corresponding entry point at \path{/ringct/borromean/src/lib.rs}. Employs no modules, and untested. Handles Borromean signatures and Borromean range proofs.}
    }

    \newglossaryentry{monero-bulletproofs (v0.1.0)}{
        name={\protect\texttt{monero-bulletproofs (v0.1.0)}},
        description={A standard library crate, with the corresponding entry point at \path{/ringct/bulletproofs/src/lib.rs}. Handles original bulletproofs and bulletproofs plus.}
    }

    \newglossaryentry{monero-clsag (v0.1.0)}{
        name={\protect\texttt{monero-clsag (v0.1.0)}},
        description={A standard library crate, with the corresponding entry point at \path{/ringct/clsag/src/lib.rs}. Handles CLSAG ring signatures and a FROST-like thresholdization.}
    }

    \newglossaryentry{monero-mlsag (v0.1.0)}{
        name={\protect\texttt{monero-mlsag (v0.1.0)}},
        description={A standard library crate, with the corresponding entry point at \path{/ringct/mlsag/src/lib.rs}. Employs no modules, and untested. Handles MLSAG ring signatures.}
    }

    \newglossaryentry{monero-primitives (v0.1.0)}{
        name={\protect\texttt{monero-primitives (v0.1.0)}},
        description={A standard library crate, with the corresponding entry point at \path{/primitives/src/lib.rs}.}
    }

    \newglossaryentry{monero-generators (v0.4.0)}{
        name={\protect\texttt{monero-generators (v0.4.0)}},
        description={A standard library crate, with the corresponding entry point at \path{/primitives/src/lib.rs}.  Handles hashing to elliptic curve group elements, and computing fixed generators for use in the Monero protocol}
    }

    \newglossaryentry{monero-io (v0.1.0)}{
        name={\protect\texttt{monero-io (v0.1.0)}},
        description={A standard library crate with entry point at \path{/io/src/lib.rs}. Employs no modules, and untested.  Handles reading and writing various data structures used in Monero protocol computations (e.g.\ bytes, scalars, group elements, lists whose entries are the same type)}
    }
    
    \newglossaryentry{decoys-module}{
        name={\protect\path{/wallet/src/decoys.rs}},
        description={The module handling decoys.}
    }

    \newglossaryentry{extra-module}{
        name={\protect\path{/wallet/src/extra.rs}},
        description={The module handling the extra field of transactions.}
    }

    \newglossaryentry{output-module}{
        name={\protect\path{/wallet/src/output.rs}},
        description={The module handling transaction outputs.}
    }

    \newglossaryentry{scan-module}{
        name={\protect\path{/wallet/src/scan.rs}},
        description={The module handling scanning.}
    }

    \newglossaryentry{view-pair-module}{
        name={\protect\path{/wallet/src/view_pair.rs}},
        description={The module handling the (public-spend, private-view) keys.}
    }

    \newglossaryentry{send-module}{
        name={\protect\path{/wallet/src/send/mod.rs}},
        description={The module handling the sending transactions.}
    }

    \newglossaryentry{block-module}{
        name={\protect\path{/src/block.rs}},
        description={The module handling blocks.}
    }

    \newglossaryentry{merkle-module}{
        name={\protect\path{/src/merkle.rs}},
        description={Module for handling Merkle trees}
    }

    \newglossaryentry{ring-signatures-module}{
        name={\protect\path{/src/ring_signatures.rs}},
        description={Module for handling ring signatures}
    }

    \newglossaryentry{ringct-module}{
        name={\protect\path{/src/ringct.rs}},
        description={Module for handling ring confidential transactions}
    }

    \newglossaryentry{transaction-module}{
        name={\protect\path{/src/transaction.rs}},
        description={Module for handling transactions}
    }

    \newglossaryentry{base58-module}{
        name={\protect\path{/wallet/address/src/base58check.rs}},
        description={Module for handling base58 enc/dec}
    }

    \newglossaryentry{monero-serai-entry-point}{
        name={\protect\path{/src/lib.rs}},
        description={Module for handling RPC calls for communicating on the Monero network.}.
    }
    
    \newglossaryentry{wallet-tests}{
        name={\protect\path{/wallet/src/tests/runner/mod.rs}},
        description={Testing module for \texttt{monero wallet (v0.1.0)}}
    }

    \newglossaryentry{wallet-entry-point}{
        name={\protect\path{/wallet/src/lib.rs}},
        description={The entry point to the \gls{monero-wallet (v0.1.0)} crate}
    }

    \newglossaryentry{monero-simple-request-rpc-entry-point}{
        name={\protect\path{/rpc/simple-request/src/lib.rs}},
        description={The entry point to the \gls{monero-simple-request-rpc (v0.1.0)} crate}
    }
    
    \newglossaryentry{monero-rpc-entry-point}{
        name={\protect\path{/rpc/src/lib.rs}},
        description={Module for handling RPC calls for communicating on the Monero network.}.
    }

    \newglossaryentry{monero-serai-tests}{
        name={\protect\path{/src/tests/mod.rs}},
        description={Testing module for handling \gls{monero-serai (v0.1.4-alpha)} tests}
    }

    \newglossaryentry{address-tests}{
        name={\protect\path{/wallet/address/src/tests.rs}},
        description={Testing module for \gls{monero-address (v0.1.0)} tests}
    }
    
    \newglossaryentry{borromean-entry-point}{
        name={\protect\path{/ringct/borromean/src/lib.rs}},
        description={Entry point to \gls{monero-borromean (v0.1.0)}}
    }
    
    \newglossaryentry{bulletproofs-entry-point}{
        name={\protect\path{/ringct/bulletproofs/src/lib.rs}},
        description={Entry point to \gls{monero-bulletproofs (v0.1.0)}}
    }
    
    \newglossaryentry{bp-batch-verifier-module}{
        name={\protect\path{/ringct/bulletproofs/src/batch_verifier.rs}},
        description={Module for handling batch verification of bulletproofs}
    }

    \newglossaryentry{bp-core-module}{
        name={\protect\path{/ringct/bulletproofs/src/core.rs}},
        description={Module for handling the core folding computation of bulletproofs.}
    }

    \newglossaryentry{bp-point-vector-module}{
        name={\protect\path{/ringct/bulletproofs/src/point_vector.rs}},
        description={Module for handling the vectors of group elements in bulletproofs.}
    }

    \newglossaryentry{bp-scalar-vector-module}{
        name={\protect\path{/ringct/bulletproofs/src/scalar_vector.rs}},
        description={Module for handling the vectors of field elements/scalars in bulletproofs.}
    }

    \newglossaryentry{bp-original-module}{
        name={\protect\path{/ringct/bulletproofs/src/original/mod.rs}},
        description={Module for handling the original bulletproofs}
    }

    \newglossaryentry{bp-plus-module}{
        name={\protect\path{/ringct/bulletproofs/src/plus/mod.rs}},
        description={Module for handling bulletproofs plus}
    }

    \newglossaryentry{bp-test-module}{
        name={\protect\path{/ringct/bulletproofs/src/plus/mod.rs}},
        description={Module for handling bulletproofs tests}
    }

    \newglossaryentry{monero-clsag-entry-point}{
        name={\protect\path{/ringct/clsag/src/lib.rs}},
        description={Entry point for \gls{monero-clsag (v0.1.0)}}
    }
   
    \newglossaryentry{clsag-multisig-module}{
        name={\protect\path{/ringct/clsag/src/multisig.rs}},
        description={Module for handling CLSAG signatures.}
    } 

    \newglossaryentry{clsag-tests}{
        name={\protect\path{/ringct/clsag/src/tests.rs}},
        description={Test module for CLSAG signatures.}
    } 

    \newglossaryentry{monero-mlsag-entry-point}{
        name={\protect\path{/ringct/clsag/src/tests.rs}},
        description={Entry point for \gls{monero-mlsag (v0.1.0)}}
    } 

    \newglossaryentry{monero-primitives-entry-point}{
        name={\protect\path{/primitives/src/lib.rs}},
        description={Entry point for \gls{monero-primitives (v0.1.0)}}
    } 

    \newglossaryentry{unreduced-scalar-module}{
        name={\protect\path{/primitives/src/unreduced_scalar.rs}},
        description={Module for handling unreduced scalars.}
    } 

    \newglossaryentry{monero-primitives-tests}{
        name={\protect\path{/primitives/src/tests.rs}},
        description={Testing module for \gls{monero-primitives (v0.1.0)}}
    } 

    \newglossaryentry{monero-generators-entry-point}{
        name={\protect\path{/generators/src/lib.rs}},
        description={Entry point for \gls{monero-generators (v0.4.0)}}
    } 

    \newglossaryentry{hash-to-point-module}{
        name={\protect\path{/primitives/src/hash_to_point.rs}},
        description={Module for handling hashing data to elliptic curve group elements}
    } 
    
    \newglossaryentry{monero-generators-tests}{
        name={\protect\path{/primitives/src/tests/mod.rs}},
        description={Testing module for \gls{monero-generators (v0.4.0)}}
    } 

    \newglossaryentry{monero-io-entry-point}{
        name={\protect\path{/io/src/lib.rs}},
        description={Entry point for \gls{monero-io (v0.1.0)}}
    } 
    
    \newglossaryentry{monero-address-entry-point}{
        name={\protect\path{/wallet/address/src/lib.rs}},
        description={Entry point for \gls{monero-io (v0.1.0)}}
    } 

    \newglossaryentry{eventuality-module}{
        name={\protect\path{/wallet/src/send/eventuality.rs}},
        description={Module for handling \gls{eventualities}}
    } 
        
    \newglossaryentry{send-multisig-module}{
        name={\protect\path{/wallet/src/send/multisig.rs}},
        description={Module for handling multisig transactions}
    } 
    
    \newglossaryentry{send-tx-module}{
        name={\protect\path{/wallet/src/send/tx.rs}},
        description={Module for handling sending transactions}
    } 
    
    \newglossaryentry{send-tx-keys-module}{
        name={\protect\path{/wallet/src/send/tx_key.rs}},
        description={Module for handling keys in sending transactions}
    } 

    \newglossaryentry{eventualities}{
        name={Eventualities},
        description={A struct for handling the eventual output from \gls{SignableTransaction}s.}
    } 

\newglossaryentry{SignableTransaction}{
    name={SignableTransaction},
    description={A struct representing a Monero transaction prepared for signing, containing necessary inputs, outputs, and metadata but without signatures or key images. Located in \path{/wallet/src/send/}, it handles fee calculation and supports transformation into fully signed transactions through both single-signer and FROST multisig processes}
    }




%%%%%%%%%%%%%%%% For Indocrypt submission 
\setlength{\parskip}{0.1\baselineskip}
\usepackage[T1]{fontenc}

\usepackage{color}
\renewcommand\UrlFont{\color{blue}\rmfamily}
\urlstyle{rm}


\usepackage{authblk} % for affiliations
\usepackage{ marvosym } % for letter symbol

% appendix table of contents
% \usepackage[toc,page,header]{appendix}
% \usepackage{minitoc}
% \renewcommand \thepart{}
% \renewcommand \partname{}

\usepackage[page,header,title]{appendix}
\usepackage{titletoc}






\title{FROSTLASS: Flexible Ring-Oriented Schnorr-like Thresholdized Linkably Anonymous Signature Scheme
% \\
% {\normalsize Scheme Formalization \& Review of Rust Implementation}
}


% \author{
%     Joshua Babb\thanks{Cypher Stack} \\ % First line for the first author
%     \and
%     Brandon Goodell\protect\footnotemark[1] \\ % First line for the second author
%     % \and
%     % Luke Parker \\
%     \and 
%     Rigo Salazar\protect\footnotemark[1] \\ % First line for the third author
%     \and
%     Freeman Slaughter\protect\footnotemark[1] \\
%     \and 
%     Luke Szramowski\protect\footnotemark[1]
% }

\author[1]{Joshua Babb}
\author[1]{Brandon Goodell}
\author[1]{Rigo Salazar}
\author[1,2,\large{\Letter}]{Freeman Slaughter} 
\author[1]{Luke Szramowski}

\affil[1]{Cypher Stack}
\affil[2]{University of South Florida, Tampa FL, USA}
\affil[\Letter]{\url{fslaughter@usf.edu}}


\date{}



\begin{document}

% \doparttoc % Tell to minitoc to generate a toc for the parts
% \faketableofcontents % Run a fake tableofcontents command for the partocs
% \part{} % Start the document part
% \parttoc % Insert the document TOC


\maketitle

\vspace{-5em}



\begin{abstract}
FROST is a pragmatic method of thresholdizing Schnorr signatures, permitting a threshold quorum of $t$ signers out of $n$ total individuals to sign for a message. This scheme improved on the state of the art, resulting in an efficient protocol that aborts in the presence of up to $t-1$ malicious users with strong resilience against chosen-message attacks, assuming the hardness of the discrete logarithm problem. In this work, we build upon the foundation introduced in FROST by presenting FROSTLASS, which additionally enjoys novel linkability criteria and anonymity guarantees under the general one-more discrete logarithm problem, utilizing a ``Schnorr-shaped hole'' technique to prove desirable security results. This scheme is highly practical, tailor-made for use on-chain in the Monero cryptocurrency; indeed, we also showcase a Rust implementation for this protocol, demonstrating its real-world application to improve the security and usability of Monero.

\keywords{Threshold signature scheme \and Rust \and One-more discrete logarithm problem.}
\end{abstract}
% \and FROST: Flexible Round-Optimized Schnorr Threshold Signatures


\section{Introduction}

\vspace{-1em}

Over the past decades, especially since Shamir's secret sharing \cite{shamir1979share} and Shoup's threshold signatures \cite{shoup2000practical}, threshold and multiparty cryptographic schemes of different flavors have become fashionable. Bellare and Neven \cite{bellare2006multi}, for example, famously proposed a framework to formalize multisignatures and to prove them secure with the generalized forking lemma - which goes back to \cite{li1988analysis}, and is used in a variety of modern cryptographic protocols, such as ring signatures \cite{zhang2002id} and Bulletproofs \cite{bunz2018bulletproofs}.

% The general forking lemma, which goes back at least to \cite{li1988analysis}, is useful in proving a wide variety of modern cryptographic schemes secure, including ring signatures preceding \cite{zhang2002id} and the bulletproofs zero-knowledge proving system proposed in \cite{bunz2018bulletproofs}. 

Concise linkable spontaneous anonymous group (CLSAG) signatures, proposed in \cite{clsag} and built from the LSAG signatures of \cite{liu2004linkable}, are Schnorr-like ring signatures used in the Monero cryptocurrency protocol.
A na\"{i}ve thresholdization of CLSAG signatures, called \textit{thring signatures}, was proposed in \cite{goodell2018thring}, building off of the linkable spontaneous anonymous group (LSAG) signatures, which are used in the Monero cryptocurrency protocol. The FROST approach to thresholdizing Schnorr signatures, first described in \cite{komlo2021frost}, is sufficiently flexible to work for CLSAG signatures, and are superior to the thring signatures of \cite{goodell2018thring}.

% An opinionated Rust implementation of every major component of the Monero protocol at \cite{SeraiRepo}, written by Luke Parker (kayabaNerve), contains an implementation of FROSTLASS. Herein, we formalize FROSTLASS, present a novel definition of linkability, and prove FROSTLASS strongly unforgeable up to the hardness of the $\kappa$-one-more discrete logarithm problem, and statistically linkable.

An opinionated Rust implementation of every major component of the Monero protocol at \cite{SeraiRepo} contains an implementation of FROSTLASS. Herein, we formalize FROSTLASS, present a novel definition of linkability, and prove FROSTLASS strongly unforgeable up to the hardness of the $\kappa$-one-more discrete logarithm problem, and statistically linkable.

\vspace{-1em}

% \subsection{Change Log}

% This document may be updated occasionally, especially if security-sensitive results come to light. We summarize such changes here.
% \begin{itemize}
% \item 15 March 2025. Initial preprint.
% \end{itemize}

\section{Notation and Background Definitions}

\vspace{-0.5em}

\subsection{Notation}

\vspace{-0.5em}

% Notation from \cite{clsag} conflicts with the notation from \cite{frost}, and this scheme was first proposed in \cite{rust} with its own notation. Consequently, we present a ``Rosetta stone'' matching the notation in this paper with these other three sources in Table \cref{table:rosetta_stone}.

% For a set $S$, $\mathcal{P}(S)$ denotes the set of subsets of $S$, and $\mathcal{S}_S$ denotes the symmetric group on $S$. Instead of writing $\mathcal{S}_{[n]}$, we simplify notation by writing $\mathcal{S}_n$. We use $x \sample S$ to indicate $x$ is a single-observation independent sample from the set $S$ under the uniform distribution, and we use $\underline{x} = (x_1, \ldots, x_n) \sample S$ to indicate $n$ independent uniform samples. If $f:S \to T$ is a function, we use $x \mapsto y$ to indicate that $y = f(x)$. For an algorithm $\mathcal{A}$, we use $y \leftarrow \mathcal{A}(x)$ to denote the event that $\mathcal{A}$ inputs $x$ and outputs $y$.

% Let $q$ denote a prime modulus, and let $d \geq 2$.
% Let $\msg \in \bitstrings$ denote a finite-length bitstring message.
% We denote the set $\left\{1,2,\ldots,n\right\} = [n]$. We let $\mathcal{S}_n$ denote the symmetric group on $n$ letters.
% We generally write tuples with an underline, e.g.\ if $n \geq 1$ is an integer and $x_1, \ldots, x_n$ are some objects, we write the tuple $(x_1, \ldots, x_n) = \underline{x}$, with a few exceptions (e.g.\ keys).
% We abuse subset notation for tuples, so that $\underline{x} \subseteq \underline{y}$ denotes the existence of a permutation $\sigma \in \mathcal{S}_{\texttt{len}(\underline{y})}$ such that $y_{\sigma(i)} = x_i$ for each $1 \leq i \leq \texttt{len}(\underline{x})$.
% We let $\rng_\gamma$ denote a random number generator with seed $\gamma\in\bitstrings$.

% Let $\Zq$ the equivalence classes of integers modulo $q$, i.e.\ the field with $q$ elements; we refer to elements of $\Zq$ as \textit{scalars}. We typically use miniscule notation $x, y, z, \ldots$ to denote scalars (but not all miniscule variables are scalars).
% We let $\G$ represent an elliptic curve group with order $q$ written \textit{additively}; we refer to elements of $\G$ as \textit{points}. 
% We typically use majuscule notation $X, Y, Z, \ldots$ to denote points (but not all majuscule variables are points).
% Since $\G$ has order $q$, we may handle $\G$ as a $\Zq$ module, with module multiplication of any $G \in \G$ by any $x \in \Zq$ defined by interpreting $x$ as an unsigned integer on $\left\{0, 1, \ldots, q-1\right\}$ and setting $X = xG = \underbrace{G + G + \cdots + G}_{x\text{ summands}}$. 
% Any fixed $G \in \G$ induces a canonical function $\Zq \to \G$ defined by mapping scalars to points by $x \mapsto xG$. 
% We use the same character in different cases to describe points corresponding to scalars under this canonical function, i.e.\ $X = xG$, $Y = yG$, etc. 

% Now fix $G \in \G$. 
% Denote $\underline{G} = (G, G, \ldots, G) \in \G^d$. 
% We let $-\circ-:\Zq \times \G \to \G$ denote the Hadamard product mapping $(\underline{x}, \underline{Y}) \mapsto (x_iY_i)_i$.
% Let $H_{\Zq}: \bitstrings \to \Zq$, $H_{\G}:\bitstrings \to \G$, $H_\secpar: \bitstrings \to \left\{0,1\right\}^{\secpar}$ be cryptographic hash functions. We denote domain separating tags $\texttt{dst} \in \bitstrings$ and label them with descriptive subscripts.
% % We define the \textit{linking tag function} $\phi:\Zq \to \G$ by mapping $x \mapsto xH_{\G}(X)$, where $X = xG$ as above.


% In the sequel, a Lagrange interpolation of threshold keyshares is a \textit{threshold combination}, and a linear combination of keys with coefficients decided by random oracle is a \textit{key aggregation}.

% Given a specification of an algorithm, we say the algorithm is \textit{honestly computed} if the execution of the algorithm follows the specification exactly. We say the algorithm is \textit{semi-honestly computed} if all the specified steps occur in the specified order, possibly with other additional steps before, between, or after the specified steps.

 


% Similarly, all algorithms in the sequel may output an indexed symbol in the instance of failure, e.g.\ $\bot_{\sign, \texttt{idx}}, \bot_{\verify, \texttt{idx}}$ for indices $\texttt{idx}$, where the indices indicate distinct causes of failure; we omit these symbols for clarity. 

% Similarly, all algorithms in the sequel may input and output some auxiliary data, e.g.\ $\keygen(n, t, \texttt{aux}_{\keygen,in}) \to (\delta, \texttt{aux}_{\keygen,out})$, but we omit these auxiliary data for clarity except when necessary to specify them.

% Given any randomized algorithm $\mathcal{A}$ which outputs distinct failure symbols or some output $\texttt{out}$, we define the \textit{advantage} of $\mathcal{A}$ to be the probability that $\mathcal{A}$ does not output a failure symbol. We denote this probability with $\texttt{Adv}_\mathcal{A}$.

% In the sequel, we let $t \in \mathbb{R}_{> 0}$ denote a positive real number, we let $\epsilon \in [0,1]$ denote a probability, $n \in \bbn$ denote a number of keyholders, and $r \in \bbn$ denote a superthreshold number of keyholders.

Tuples are denoted with underlines, $\underline{x} = (x_1, \ldots, x_n)$, and we abuse set notation for these, e.g.\ $x_1 \in \underline{x}$. The set of all finite-length bitstrings is denoted with $\bitstrings$.  For $n \in \bbn$, denote the set $\left\{1, 2, \ldots, n\right\}$ with $\left[n\right]$. For sets $X, Y$ with $X \subseteq Y$, denote the set $\left\{y \in Y \mid y \notin X\right\}$ with $\overline{X}$. 

Denote a prime modulus with $q \in \bbn$, an abelian group of order $q$ with $\G$, and a generator of $\G$ with $G \in \G$. We say the tuple $(q, \G, G)$ are \textit{group parameters}. Given $\underline{x} = (x_1, \ldots, x_n) \in \Zq^n$ and $\underline{G} = (G_1, \ldots, G_n) \in \G^n$, we denote the Shur product $\underline{x} \circ \underline{G} = (x_1G_1, \ldots, x_n G_n)$.


Denote ``big-oh'' notation with $O$ and denote random oracles with $\mathcal{O}$. Denote algorithm run times with $t \geq 0$ and success probabilities with $\epsilon \in [0,1]$. Denote the event that a PPT algorithm $\mathcal{A}$ inputs some $\texttt{in}$ and outputs some $\texttt{out}$ with $\texttt{out} \leftarrow \mathcal{A}(\texttt{in})$. We use the same notation for oracles, but we refer to the inputs as queries, say $\texttt{query}$, and outputs as responses, say $\texttt{resp}$.

\vspace{-1.5em}

\subsection{Definitions}\label{sec:definitions}

\vspace{-0.5em}

\begin{definition}[$\kappa$ Random Oracle Distinguishing]\label{def:distinguisher}
Let $\kappa \geq 0$ be an integer, let $S, T$ be sets, $\mathcal{O}:S \to T$ be a random oracle, and $\phi: S \to T$ a function. Any PPT $(t,\epsilon)$-algorithm $\mathcal{A}$ which plays the following game is an $(\phi,\kappa)$-distinguisher.

\vspace{-1em}

\begin{enumerate}
\item The challenger samples $b \sample \left\{0,1\right\}$ and grants $\mathcal{A}$ access to an oracle $\mathcal{O}^\prime_b$, where 
\begin{enumerate}
\item $\mathcal{O}^\prime_0$ is a simple wrapper for $\mathcal{O}$, and
\item $\mathcal{O}^\prime_1$ is a simple wrapper for $\phi$.
\end{enumerate}
\item $\mathcal{A}$ outputs a bit $b^\prime$, succeeding if and only if $b^\prime = b$ and $\mathcal{O}^\prime_b$ was queried at most $\kappa$ times.
\end{enumerate}
\end{definition}

\vspace{-1em}

\begin{definition}[$\kappa$-OMDL: One-More-Than-$\kappa$ Discrete Logarithms over $G \in \G$]\label{def:omdl}
Let $\kappa \geq 0$ be an integer. Let $ \Phi = \left\{(q_\secpar, \G_\secpar, G_\secpar)\right\}_{\secpar \in \bbn}$ be a parameterized family of group parameters. Let $t \geq 0$ and $\epsilon \in [0, 1]$ be real numbers. We say any PPT algorithm $\mathcal{A}$ that can successfully play the following game in time at most $t$ and with probability at least $\epsilon$ is a $(t,\epsilon)$-player of the one-more-than-$\kappa$ discrete logarithms game over $G_\secpar \in \G_\secpar$.

\vspace{-1em}

\begin{enumerate}
\item The challenger grants $\mathcal{A}$ access to a key generation oracle $\keyOracle:\left\{\ast\right\} \to \G_\secpar$ and a corruption oracle $\corruptionOracle: \G_\secpar \to \mathbb{Z}_{q_\secpar}$ which work as follows.
\begin{enumerate}
\item A valid query made to $\keyOracle$ is a simple request for a new key, which we model with a dummy singleton domain $\left\{\ast\right\}$. The response is some point $\texttt{resp}=X \in \G_\secpar$. We say the response is a \textit{challenge key}. Let $\challengeKeySet = \left\{X \in \G_\secpar \mid X \leftarrow \keyOracle\text{ occurred}\right\}$ denote the set of all responses from $\keyOracle$.

\item A valid query made to $\corruptionOracle$ a challenge key, $X \in \challengeKeySet$. The response to a valid query $X$ is a scalar $x \in \mathbb{Z}_{q_\secpar}$ such that $X = xG$, and the response to an invalid query is a distinct failure symbol. Let $\corruptedKeySet \subseteq \challengeKeySet$ be the subset of valid queries made to $\corruptionOracle$ be the \textit{corrupted keys} and let $\overline{\corruptedKeySet}$ be the subset of \textit{uncorrupted challenge keys}.
\end{enumerate}
   \item Eventually, the event $\texttt{out}_\mathcal{A} \leftarrow \mathcal{A}$ occurs. We say $\mathcal{A}$ succeeds at the $\kappa$-OMDL game if and only if all the following hold in this event:
\begin{enumerate}
\item $\left|\challengeKeySet\right| \geq \kappa + 1$,
\item $\left|\corruptedKeySet\right| \leq \kappa$,
\item $\texttt{out}_{\mathcal{A}} \in \mathbb{Z}_{q_\secpar}^{\kappa+1}$, and
\item $\left\{xG \mid x \in \texttt{out}_{\mathcal{A}}\right\} \subseteq \challengeKeySet$

\end{enumerate}
\end{enumerate}
If $t \in \polysecpar$ implies $\epsilon \in \negl$ for all $(t, \epsilon)$-players, then the $\kappa$-OMDL game is hard over $\Phi$.
\end{definition}

% In the sequel, we leave $\secpar$ implicit, suppressing it in our notation for clarity.

\vspace{-1em}

Note that the $0$-OMDL game is simply the discrete logarithm game. Moreover, an adaptive variation of this game is natural, where  $\kappa$ is determined in each instance of the game by the number of corruption oracle queries made by the adversary.



\begin{oracle}
    \centering
    \begin{suboracle}[ht]{0.2\textwidth}
        \begin{tabular}{|l|}
        \hline
        \multicolumn{1}{|c|}  {\textbf{Oracle} $\keyOracle(\ast)$} \\
        \hline 
        $x \lsamp \Zq$ \\
        $X=xG$ \\
        $\challengeKeySet = \challengeKeySet \cup \left\{X\right\}$ \\
        \textbf{return } $X$ \\
        \hline
        \end{tabular}
    \end{suboracle}
    \hspace{1em}
    \begin{suboracle}[ht]{0.3\textwidth}
        \begin{tabular}{|l|}
        \hline
        \multicolumn{1}{|c|}  {\textbf{Oracle} $\corruptionOracle(X)$} \\
        \hline 
        \textbf{if} $X \in \challengeKeySet$ \\ \quad \quad
        $x=\log_G{X}$ \\ \quad \quad 
        $\corruptedKeySet = \corruptedKeySet \cup \left\{X\right\}$ \\ \quad \quad
        \textbf{return} $x$ \\
        \textbf{else return} $\perp$ \\
        \hline
        \end{tabular}
    \end{suboracle}
\caption{The key generation and corruption oracles for the $\kappa$-OMDL game.}
\label{oracle:OMDL}
\end{oracle}

\begin{game}
    \centering
    \begin{tabular}{|l|}
    \hline
    \multicolumn{1}{|c|}  {\textbf{Game} $\kappa\text{-OMDL}(\underline{x})$} \\
    \hline 
    \textbf{if} $\left|\challengeKeySet\right| \geq \kappa+1$  
    \textbf{and }  $\left|\corruptedKeySet\right| \leq \kappa$ \\
    \textbf{and} $\underline{x} \in \Zq^{\kappa+1}$ \textbf{and} $\underline{x} \circ \underline{G} \subseteq \challengeKeySet$\\
    \quad \quad \textbf{return} $1$ \\
    \textbf{else return} $0$ \\
    \hline
    \end{tabular}
    \caption{Success condition for the $\kappa$-OMDL game.}
    \label{game:OMDL}
\end{game}




\vspace{-1em}

\begin{definition}[General Forking Algorithm]\label{def:general_forking_algorithm}
Let $X, Y, H$ be finite sets, $\kappa \geq 1$ an integer parameter, and let $\mathcal{A}$ be a PPT algorithm which uses a random tape $\tau \in \bitstrings$, inputs some $(x, \underline{h}) \in X \times H^\kappa$, and  outputs a pair $(i, y) \in [\kappa] \times Y$ or a distinct failure symbol. Then the algorithm specified below, $\fork_{\mathcal{A}}$, is a PPT algorithm which inputs $x \in X$, outputs $(i, y, y^\prime) \in [\kappa] \times Y^2$ or a distinct failure symbol, and is called the \textit{general forking algorithm} for $\mathcal{A}$.
\begin{enumerate}
\item Sample $\tau \sample \bitstrings$ for $\mathcal{A}$ to use in both executions.
\item Sample $\underline{h}, \underline{h}^\prime \sample H^\kappa$.
\item Compute $\texttt{out} \leftarrow \mathcal{A}(x, \underline{h}; \tau)$.
\item If $\texttt{out}$ is a failure symbol, output a distinct failure symbol and terminate. Otherwise, $\texttt{out}$ is not failure symbol, so parse $(i, y) := \texttt{out}$.
\item Set $\underline{h}^* = (h_1, \ldots, h_{i-1}, h^\prime_i, h^\prime_{i+1}, \ldots, h^\prime_\kappa)$.
\item Compute $\texttt{out}^\prime \leftarrow \mathcal{A}(x, \underline{h}^*; \tau)$.
\item If $\texttt{out}^\prime$ is a failure symbol, output a distinct failure symbol and terminate. Otherwise, $\texttt{out}$ is not a failure symbol, so parse $(i^\prime, y^\prime) := \texttt{out}^\prime$.
\item If $i \neq i^\prime$ or $h_i = h_{i^\prime}^*$, then output a distinct failure symbol and terminate.
\item Otherwise, output $(i, y, y^\prime)$.
\end{enumerate}
\end{definition}


\begin{lemma}[General Forking Lemma]\label{lem:general_forking_lemma}
For any finite sets $X, H$, for any algorithm $\mathcal{A}$ as in  \cref{def:general_forking_algorithm} which runs in time at most $t$ and fails with probability at most $\epsilon$, for any probability mass function $F$ over $X$, the general forking algorithm $\fork_\mathcal{A}$ has advantage satisfying the following
\[\texttt{Adv}_{\fork_\mathcal{A}} \geq \epsilon \left(\frac{\epsilon}{\kappa} - \frac{1}{\left|H\right|}\right)\] where this probability is measured over $F$ and all randomness used in sampling.
\end{lemma}


\begin{definition}[LTM: Linkable Thring Multisignatures]\label{def:ltm}
A tuple of algorithms $(\setup, \keygen, \sign, \\ \combine, \verify, \link)$ as follows.
\begin{enumerate}
\item $\setupIO$. Input a security parameter $\secpar \in \bbn$, and output some public parameters $\params_\secpar$, which includes the description of secret signing key shares $\mathcal{SK}$, public verification key shares $\mathcal{VK}$, total verification keys $\mathcal{TVK}$, messages $\mathcal{MSG}$, signatures challenges $\mathcal{CH}$, partial signature shares $\mathcal{PSIG}$, and signatures $\mathcal{SIG}$.

\item $\keygenIO$. An interactive probabilistic algorithm executed by some \textit{capacity} of $n \geq 1$ participants called \textit{threshold keyholders}. Users share as common input the capacity $n$ and threshold $r \in n$. Output  \textit{total verification key} $\tvk \in \mathcal{TVK}$, \textit{public verification key shares} $\VK=(\vk_i)_{i=1}^{n} \in \mathcal{VK}^n$, and \textit{secret signing key shares} $\SK = (\sk_i)_{i=1}^{n} \in \mathcal{SK}^n$.



\item $\signIObase$. Non-interactive probabilistic algorithm executed by a threshold keyholder. Input a message $\msg \in \mathcal{MSG}$, a tuple of $m \geq 1$ total verification keys $\ring = (\tvk_j)_{j=1}^{m} \in \mathcal{TVK}^m$ called a \textit{ring}\footnote{A better term would be \textit{anonymity tuple}, but we keep with tradition.}, some $r \geq 1$ public verification key shares $\VK = (\vk_i)_{i=1}^{r} \in \mathcal{VK}^r$ called \textit{signers' coalition key shares},  and a secret key share $\sk \in \mathcal{SK}$. Output a ring signature share $\psig \in \mathcal{PSIG}$.

\item $\combineIObase$. Non-interactive deterministic algorithm executed by a user called the \textit{combiner}. Input a message $\msg \in \mathcal{MSG}$, a ring $\ring = (\tvk_j)_{j=1}^{m} \in \mathcal{TVK}^m$,  a signers' coalition of key shares $\VK = (\vk_i)_{i=1}^{r} \in \mathcal{VK}^r$,  and ring signature shares $\psigs=(\psig_i)_{i=1}^{r} \in \mathcal{PSIG}^r$. Output a ring signature $\sig \in \mathcal{SIG}$.

\item $\verifyIObase$. Non-interactive deterministic algorithm executed by a user called the \textit{verifier}. Input message $\msg \in \mathcal{MSG}$, a ring  $\ring = (\tvk_j)_{j=1}^{m} \in \mathcal{TVK}^m$, and a ring signature $\sig \in \mathcal{SIG}$. Output a bit.

\item $\linkIObase$. A non-interactive deterministic algorithm executed by a user called the \textit{linker}.  Input ring signatures $\sig, \sig^\prime \in \mathcal{SIG}$, and output a bit.
\end{enumerate}

\end{definition}

\vspace{-1em}

\cref{def:ltm} extends naturally to a \textit{verifiable} scheme by allowing the verification of signature shares with the following additional algorithm.
Adding this additional level of verifiability requires modifying \cref{def:correctness} below in the natural way.

\vspace{-1em}

\begin{itemize}
\item $\verifyshareIObase$. Non-interactive deterministic executed by a user called a \textit{share verifier}. Input message $\msg \in \mathcal{MSG}$, a ring $\ring = (\tvk_j)_{j=1}^{m} \in \mathcal{TVK}^m$, a signers' coalition of key shares $\VK=(\vk_i)_{i=1}^{r}$, and a ring signature share $\psig \in \mathcal{PSIG}$. Outputs a bit.
\end{itemize}

\vspace{-1em}

Any of the algorithms in \cref{def:ltm} may input or output auxiliary data $\texttt{aux}$, which we only include in notation when relevant. Following our convention for group parameter notation, we leave $\params_\secpar$ implicit in our notation, as all algorithms require it.

\vspace{-1em}

\begin{definition}\label{def:correctness}
Let $\Pi$ be an LTM scheme. We define correctness using the following events.
\begin{enumerate}
\item Let $E_1$ be the event in which some signers' coalitions of key shares $\VK^\prime, \VK^{\prime \prime} \subseteq \VK$ is used to compute ring signature shares $\psig_i^\prime$ and $\psig_i^{\prime \prime}$ semi-honestly. That is to say, the following holds.
\begin{enumerate}
\item For some $\msg^\prime, \msg^{\prime \prime} \in \mathcal{MSG}$,
\item for some $n, r \in \bbn$ such that  $r \in [n]$ and some event $(\tvk, \VK,  \SK) \leftarrow \keygen\keygenIshort$ occurs, 
\item for some $\VK^\prime, \VK^{\prime \prime}$
such that $\VK^\prime, \VK^{\prime \prime} \subseteq \VK$, $r^\prime = \left|\VK^\prime\right|$, $r^{\prime \prime} = \left|\VK^{\prime \prime}\right|$, and  $r \leq \min\left\{r^\prime, r^{\prime \prime}\right\}$,
\item for some $\sigma^\prime \in \mathcal{S}_n$ such that, for every $i \in [r^\prime]$, $\vk^{\prime}_i = \vk_{\sigma^\prime(i)}$ and  $\sk^\prime_i = \sk_{\sigma^\prime(i)}$,
\item for some $\sigma^{\prime\prime} \in \mathcal{S}_n$ such that, for every $i \in [r^{\prime \prime}]$, $\vk^{\prime\prime}_i = \vk_{\sigma^{\prime\prime}(i)}$ and  $\sk^{\prime\prime}_i = \sk_{\sigma^{\prime\prime}(i)}$,
\item for some $\ring^\prime, \ring^{\prime \prime} \subseteq \mathcal{TVK}$ such that $\tvk \in \ring^{\prime} \cap \ring^{\prime \prime}$,

\item for each $i \in [r^\prime]$, $\psig_i^\prime \leftarrow \sign(\msg^\prime, \ring^\prime, \VK^\prime,  \sk^\prime_i)$, and
\item for each $i \in [r^{\prime \prime}]$, $\psig_i^{\prime\prime} \leftarrow \sign(\msg^{\prime\prime}, \ring^{\prime \prime}, \VK^{\prime\prime},  \sk^{\prime \prime}_i)$.
\end{enumerate}

\item Let $E_1^*$ be a similar event in which some $\VK^{**} \subseteq \VK^*$ compute ring signature shares $\psig^*_i$ semi-honestly from a different $\tvk^*$, i.e.\ all the following hold.
\begin{enumerate}
\item For some $\msg^* \in \mathcal{MSG}$,
\item for some $n^*, r^* \in \bbn$ such that  $r^* \in [n^*]$ and some event $(\tvk^*, \VK^*,  \SK^*) \leftarrow \keygen\keygenIshort$ occurs such that $(\tvk^*, \VK^*,  \SK^*) \neq (\tvk^\prime, \VK^\prime,  \SK^\prime)$ and $(\tvk^*, \VK^*,  \SK^*) \neq (\tvk^{\prime\prime}, \VK^{\prime\prime},  \SK^{\prime\prime})$,
\item for some $\VK^{**}$
such that $\VK^{**} \subseteq \VK^*$, $r^{**} = \left|\VK^*\right|$, and  $r^* \leq r^{**}$,
\item for some $\sigma^* \in \mathcal{S}_n$ such that, for every $i \in [r^{**}]$, $\vk^*_i = \vk_{\sigma^*(i)}$ and  $\sk^*_i = \sk_{\sigma^*(i)}$,
\item for some $\ring^* \subseteq \mathcal{TVK}$ such that $\tvk^* \in \ring^*$,

\item for each $i \in [r^{**}]$, $\psig_i^{**} \leftarrow \sign(\msg^*, \ring^*, \VK^*,  \sk^*_i)$.
\end{enumerate}




\item Let $E_2 \subseteq E_1^* \cap E_1$ be the event that the ring signature shares $\psig_i^\prime$, $\psig_i^{\prime \prime}$, and $\psig_i^{*}$ are combined semi-honestly, i.e.\ all of the following hold.
\begin{enumerate}
\item $\sig^\prime \leftarrow \combine(\msg^\prime, \ring^\prime, \psigs^\prime)$,
\item $\sig^{\prime\prime} \leftarrow \combine(\msg^{\prime\prime}, \ring^{\prime\prime},  \psigs^{\prime\prime})$,
\item $\sig^* \leftarrow \combine(\msg^*, \ring^*, \psigs^*)$.
\end{enumerate}

\item  Let $E_3 \subseteq E_2$ be the event that the combined signatures are valid, i.e.\ all the following hold.
\begin{enumerate}
\item $\verify(\msg^{\prime}, \ring^{\prime}, \sig^\prime) = 1$,
\item $\verify(\msg^{\prime\prime}, \ring^{\prime\prime}, \sig^{\prime\prime}) = 1$, and
\item $\verify(\msg^{\prime\prime}, \ring^{\prime\prime}, \sig^{\prime\prime}) = 1$.
\end{enumerate}

\item Let $E_4 \subseteq E_3$ be the event that $\link$ is commutative, i.e.\ all the following hold.
\begin{enumerate}
\item $\link(\sig^\prime, \sig^{\prime \prime}) = \link(\sig^{\prime \prime}, \sig^\prime)$,
\item $\link(\sig^\prime, \sig^*) = \link(\sig^*, \sig^\prime)$, and
\item $\link(\sig^*, \sig^{\prime \prime}) = \link(\sig^{\prime \prime}, \sig^*)$
\end{enumerate}

\item Let $E_5 \subseteq E_2$ that $\link(\sig^\prime, \sig^{\prime \prime}) = 1$.

\item Let $E_6 \subseteq E_3$ that $\link(\sig^\prime, \sig^*) =  \link(\sig^*, \sig^{\prime \prime})=0$.

\vspace{-1em}

\end{enumerate}
We say $\Pi$ has \textit{correct ring signature share verification} if $\mathbb{P}[E_2] = 1$, has \textit{correct ring signature verification} if $\mathbb{P}[E_4] = 1$, has \textit{commutative linking} if $\mathbb{P}[E_5]=1$, has \textit{correct positive linkability} if $\mathbb{P}\left[E_6\right]=1$, and has \textit{correct negative linkability} if $\mathbb{P}\left[E_7\right]=1$, where these probabilities are computed over all choices of $n, r, n^*, r^*, \msg^\prime, \msg^{\prime \prime}, \msg^*$, all executions of $\keygen$, all choices of $\VK^\prime, \VK^{\prime \prime}, \VK^*$, and all randomness used by all algorithms. If $\Pi$ satisfies all four notions of correctness, we simply say $\Pi$ is a \textit{correct} LTM. 
\end{definition}


% For convenience, we present the following common setup useful for linkability and unforgeability.

\vspace{-1em}

\begin{definition}[Common Setup with Key Generation, Corruption, and Signing Oracles]\label{def:common_setup}
Let $\Pi$ be an LTM scheme. Let $\mathcal{A}$ be any PPT algorithm which runs in time at most $t > 0$, and successfully plays the following game with probability at least $\epsilon \in [0,1]$.

\vspace{-1em}

\begin{enumerate}
\item $\mathcal{A}$ is granted to oracles $\keyOracle$, $\corruptionOracle$, and $\signingOracle$ as follows.
\begin{enumerate}

\item $(\tvk, \VK) \leftarrow \keyOracle(n, r).$ A valid query made to $\mathcal{O}_{\texttt{key}}$ is a simple request for $r$-of-$n$ keys, which we model with the pair $(n, r)$ such that $r \in [n]$. The response to a valid query is some $\texttt{resp} = (\tvk, \VK) \in \mathcal{TVK} \times \mathcal{VK}^n$, and the response to an invalid query is a distinct failure symbol. Let $\challengeKeySet = \left\{(\tvk, \VK) \mid \exists (n, r), (\tvk, \VK) \leftarrow \keyOracle(n, r)\right\}$ denote the set of all responses from $\keyOracle$.

\begin{oracle}
    \centering
        \begin{tabular}{|l|}
        \hline
        \multicolumn{1}{|c|}  {\textbf{Oracle} $\keyOracle(n,r)$} \\
        \hline 
        \textbf{if} $r \in [n]$ \\  
        \quad \quad \textbf{sample} $(\tvk, \VK)$ \\
        \quad \quad $\challengeKeySet = \challengeKeySet \cup \left\{(\tvk, \VK)\right\}$ \\
        \quad \quad \textbf{return} $(\tvk, \VK)$ \\
        \textbf{else return} $\perp$ \\
        \hline
        \end{tabular}
\caption{The key generation oracle in the game of common setup.}
\label{oracle:key}
\end{oracle}

\item $\sk \leftarrow \corruptionOracle(i, \tvk, \VK).$ A valid query made to $\corruptionOracle$ is some $\texttt{query}=(i, \tvk, \VK)$ where $(\tvk, \VK) \in \challengeKeySet$ is associated with some $(n, r) \in \bbn^2$ such that $r \in [n]$ and $(\tvk, \VK) \leftarrow \keyOracle(n,r)$ occurred, and $i$ is an index in $[n]$. The response to a valid query is a secret signing key $\sk_i$ corresponding to $\vk_i \in \VK$, and the response to an invalid query is a distinct failure symbol. 

Upon success, we say the verification key share $\vk_i$ has been corrupted, and if $r$ or more key shares have been corrupted associated with $\tvk$, then we say $\tvk$ has been totally corrupted. Let $\corruptedKeyShareSet = \left\{\vk_i \mid \sk_i \leftarrow \corruptionOracle(i, \tvk, \VK)\text{ occurred}\right\}$ be the set of corrupted key shares and let $\corruptedTotalKeys$ be the set of totally corrupted keys.



\begin{oracle}
    \centering
        \begin{tabular}{|l|}
        \hline
        \multicolumn{1}{|c|}  {\textbf{Oracle} $\corruptionOracle(i, \tvk, \VK)$} \\
        \hline 
        \textbf{if} $(\tvk, \VK) \lar \keyOracle(n,r)$\textbf{ and }$i \in [n]$\textbf{ then } \\ 
        \quad \quad $\corruptedKeyShareSet = \corruptedKeyShareSet \cup \left\{\vk_i\right\}$ \\ 
        \quad \quad \textbf{if} $|\VK \cap \corruptedKeyShareSet| \geq r$  
        \textbf{then}\\
        \quad \quad \quad \quad $\corruptedTotalKeys \lar \corruptedTotalKeys \cup \left\{\tvk\right\}$ \\
        \quad \quad \textbf{return} $\sk_i$ \\
        \textbf{else return} $\perp$ \\
        
        \hline
        \end{tabular}
\caption{The corruption oracle in the game of common setup.}
\label{oracle:corrupt}
\end{oracle}




\item $\sig \leftarrow \signingOracle(\msg, \ring, \tvk, \VK, i).$ A valid query to $\signingOracle$ is a tuple $(\msg, \ring, \tvk, \VK, i)$, where $\msg \in \bitstrings$, $\ring \in \mathcal{TVK}^m$ for some $m \in \bbn$, $\tvk \in \mathcal{TVK}$, $\VK \in \VK^r$ for some $r \in \bbn$, and $i \in \bbn$, such that all the following hold.
\begin{enumerate}
\item $\tvk \in \ring$,
\item there exists some $n$, $\VK^\prime$ such that $r \in [n]$ and $(\tvk, \VK^\prime) \leftarrow \keyOracle(n,r)$ occurred,
\item the query $\VK$ is a subset $\VK \subseteq \VK^\prime$ such that $\left|\VK\right| \geq r$, and
\item $i \in [r]$.
\end{enumerate}

\begin{oracle}
    \centering
        \begin{tabular}{|l|}
        \hline
        \multicolumn{1}{|c|}  {\textbf{Oracle} $\signingOracle(\msg, \ring, \tvk, \VK, i)$} \\
        \hline 
        \textbf{parse} $r:=\texttt{len}(\VK)$ \\
        \textbf{if} $\tvk \in \ring$ \\ 
        \textbf{and} $\exists n,r^\prime,\VK^\prime$ s.t. $(\tvk, \VK^\prime) \leftarrow \keyOracle(n,r^\prime)$ \\ 
        \textbf{and} $\VK \subseteq \VK^\prime$ \textbf{and} $r \geq r^\prime$ \textbf{ and } $i \in [r]$ \\
        \quad \quad \textbf{return} $\psig$ \\
        \textbf{else} $\perp$ \\
        \hline
        \end{tabular}
\caption{The signing oracle}
\label{oracle:sign}
\end{oracle}


The response to an invalid query is a distinct failure symbol, and the response to a valid query is a valid partial signature $\psig$ which is combinable with other valid signatures, and links to a challenge key, as follows.
\begin{itemize}
\item \textbf{Well-Formed Queries Combine to Valid Signatures.} 
If oracle response events
$\psig_{\vk^*} \leftarrow \signingOracle(\msg, \ring, \tvk, \VK, \vk^*)$ occur for each  $\vk^* \in \VK$, the combination of these responses
$\sig = \combine(\msg, \ring, \VK, \PSIG)$ is valid, $\verify(\msg, \ring, \sig)=1$. 

\item \textbf{Links to Challenge Key.}
If $\msg^\prime$ is a message, $\VK^{\prime \prime} \subseteq \VK^\prime$ such that $\left|\VK^{\prime \prime}\right| \geq r$, $\ring^\prime$ is a ring with $\tvk \in \ring \cap \ring^\prime$, and there exist signing oracle responses for each $\vk^{**} \in \VK^{\prime \prime}$, $\psig^\prime_{\vk^{**}} \leftarrow \signingOracle(\msg^\prime, \ring^\prime, \tvk, \VK^{\prime \prime}, \vk^{**})$, then $\link(\params_\secpar, \sig, \sig^\prime)=1$ where $\sig^\prime = \combine(\msg^\prime, \ring^\prime, \VK^{\prime \prime}, \PSIG^\prime)$ is the combined signature.
\item \textbf{Verifiability.} If $\Pi$ is verifiable, then $\verifyshare(\msg, \ring, \VK, \psig)=1$
\end{itemize}



\end{enumerate}
\item Eventually, $\mathcal{A}$ outputs some $\texttt{out}_\mathcal{A}$ which includes one or more message-ring-signature triples $(\msg, \ring, \sig)$ such that all the signatures are valid (in which case we say $\mathcal{A}$ succeeds) or a distinct failure symbol (in which case we say $\mathcal{A}$ fails).
\end{enumerate}

Further assume that, if $\mathcal{A}$ requires more oracle queries allowed than the following bounds, or if $\mathcal{A}$ is about to make an oracle query which will cause the oracle to fail, then $\mathcal{A}$ outputs a distinct failure symbol and terminates.
\begin{enumerate}
\item There exists $\kappa_{\texttt{key}}$, $\kappa_{\texttt{corrupt}}$, $\kappa_{\sign} \geq 0$ such that, in every successful transcript, $\mathcal{A}$ makes at most $\kappa_{\texttt{key}}$ respective queries to $\keyOracle$, at most $\kappa_{\texttt{corrupt}}$ queries to $\corruptionOracle$, and at most $\kappa_{\sign}$ queries to $\signingOracle$. 

\item For each random oracle, say $H$, to which $\mathcal{A}$ has access, there exists as similar integer $\kappa_{H}$ such that $\mathcal{A}$ makes at most $\kappa_{H}$ queries to the corresponding random oracle $H$ in every successful transcript. 

\item There exists an integer $n_{\texttt{key}}$ such that all queries $\texttt{query} = (n, r)$ made to $\keyOracle$ satisfies $n \leq n_{\texttt{key}}$ in every successful transcript.


\end{enumerate}

If $\mathcal{A}$ succeeds with probability at least $\epsilon \in [0,1]$ is $(t,\epsilon)$-\textit{player of the game with common setup} with key generation oracle access, corruption oracle access, and signing oracle access. 

\end{definition}

Winning this game is trivial, so the notion of security against players of this game is vacuous. However, players of our unforgeability and linkability games in \cref{def:suf} and \cref{def:linkable} are also players of the game of common setup, just with nontrivial success conditions.


\begin{definition}[LTM-SUF-1: Strong Unforgeability]\label{def:suf}
Let $\Pi$ be an LTM scheme. Let $\mathcal{A}$ be any $(t,\epsilon)$-player of the game with common setup with key generation, corruption, and signing oracle access such that every successful output of $\mathcal{A}$ has some $(\msg, \ring, \sig) \in \texttt{out}_{\mathcal{A}}$ satisfying all the following.
\begin{enumerate}
\item The signature is valid, $\verify(\msg, \ring, \sig)=1$.

\item All ring members are challenge keys, $\ring \subseteq \challengeKeySet$.

\item If all the following hold, then $\link(\sig, \sig^\prime) = 1$:
\begin{enumerate}
\item there exists some
$(j, \tvk_j) \in [m] \times \ring$, 
capacity  $n \in \bbn$, and a 
threshold $r \in [n]$ such that
a key generation oracle query event $(\tvk_j, \VK) \leftarrow \keyOracle(n,r)$ occurs,
\item there exists some $\msg^\prime \in \bitstrings$, some $\ring^\prime \in \mathcal{P}(\mathcal{TVK})$ such that $\tvk_j \in \ring \cap \ring^\prime \setminus \corruptedTotalKeys$,  some signers' coalition of public verification keys $\VK^\prime \subseteq \VK$ such that $\left|\VK^\prime\right| \geq r$,  and events $\psig_{\vk^\prime} \leftarrow \signingOracle(\msg^\prime, \ring^\prime, \tvk_j, \VK^\prime, \vk^\prime)$ for each $\vk^\prime \in \VK^\prime$ which occurred, and
\item $\sig^\prime = \combine(\msg^\prime,\ring^\prime,\VK^\prime,\PSIG)$.
\end{enumerate}


\item For any $\msg^\prime$, for any $\ring^\prime$, for any $\VK^\prime$, if every event $(\psig_i \leftarrow \signingOracle(\msg^\prime, \ring^\prime, \VK^\prime, \vk_i)$ occurs for each  $\vk_i \in \VK$, then $\sig \neq \combine(\msg^\prime, \ring^\prime, \VK^\prime, \PSIG^\prime)$.
\end{enumerate}
Then we say $\mathcal{A}$ is an \textit{LTM strong forger} for $\Pi$. Moreover, if  $t \in \polysecpar$ implies $\epsilon \in \negl$ for every LTM strong forger, then we say $\Pi$ is \textit{strongly unforgeable}.
\end{definition}

We connect this definition to the definition of strong unforgeability for threshold digital signature schemes, TS-SUF-4 from \cite{bellare2022better}. Indeed, we include as ``trivial'' all ring signatures which are a superthreshold combinations of oracle-generated signature shares which all use a common query. This way, if an attacker can combine seemingly unrelated ring signature shares to obtain a valid signature, we count this as a forgery. 

However, ring signatures have their own hierarchy of security definitions, and some of these depend on how many adversarially-selected ring members are allowable in a forgery. We call the previous definition LTM-SUF-1, because an unforgeable scheme under this definition stops forgers from generating ostensibly valid signatures, but only when all ring members are challenge keys. Natural extensions may be a fruitful area of further research.


The following is, to the authors' knowledge, a novel definition of linkability for ring signatures.

\vspace{-1em}

\begin{definition}[$\kappa$-Linkability]\label{def:linkable}
Let $\Pi$ be a LTM signature scheme and $\mathcal{A}$ be a $(t,\epsilon)$-player of the game of common setup with key generation, corruption, and signing oracle access such that every successful output of $\mathcal{A}$ has some $\left\{(\msg_u, \ring_u, \sig_u)\right\}_{u\in[\kappa+1]}$ satisfying all the following properties.
\begin{enumerate}
\item For each $u \in [\kappa+1]$, $\verify(\msg_u, \ring_u, \sig_u) = 1$.


\item For each $u, v \in [\kappa+1]$, $\link(\sig_u, \sig_v) = \delta_{u,v}$, the Kronecker delta function.
\item At most $\kappa$ keys can be under adversarial control, $\left|\cup_u \ring_u \setminus \overline{\corruptedTotalKeys}\right| \leq \kappa$
\end{enumerate}

\vspace{-1em}

Then we say $\mathcal{A}$ is a \textit{$\kappa$-linkability breaker} for $\Pi$. Moreover, $t \in \polysecpar$ implies $\epsilon \in \negl$ for every $\kappa$-linkability breaker, we say $\Pi$ is $\kappa$-\textit{linkable.}
\end{definition}

\vspace{-1em}

Note that if we remove oracle access from \cref{def:linkable}, we recover the notion of pigeonhole linkability. If we retain oracle access but set $\kappa = 1$, we recover the notion of ACST linkability.

\vspace{-1.5em}

\section{FROSTLASS Construction}

\vspace{-0.5em}

We now provide a formal description of FROSTLASS. We note that the definition provided here varies from the Rust implementation \cite{SeraiRepo} to improve readability. We discuss these in \cref{sec:variations_from_implem}.

\vspace{-1em}

\begin{definition} \label{def:frostlass}
Let $F_{\texttt{PRNG}}$ be a seedable pseudorandom number generator. FROSTLASS consists of the following algorithms. 
\begin{enumerate}
\item $\setup(\secpar) \to (q,\G, G, d, \underline{H})$ where $q \geq 1$ is a prime modulus, $\G$ is an abelian group of order $q$, $G \in \G$ is a generator, $d \in \bbn$ is a key dimension, and $\underline{H}$ are the following random oracles.
\begin{enumerate}
\item $H_{\texttt{base}}:\bitstrings \to \G$,
\item $H_{\seed}:\bitstrings \to \left\{0,1\right\}^\secpar$,
\item $H_{\FROST,i}:\bitstrings \to \Zq$ for each $i \in \mathbb{N}$,
\item $H_{\lt}^*:\bitstrings \to \Zq$.
\item $H_{\lt,k}:\bitstrings \to \Zq$ for each $1 \leq k \leq d-1$,
\item $H_{\texttt{ch}}:\bitstrings \to \Zq$.
\end{enumerate}
\item $\keygen(n, r, \underline{z}) \to (\tvk, \VK, \LT, \SK)$. 
An interactive PPT algorithm which requires $n \geq 2$ participants.  Participants decide upon  a threshold $1 \leq r \leq n$, and scalars $\underline{z} = z_1, \ldots, z_{d-1} \in \Zq$ via secure side channel; they share these data as common input.  Participants do the following. 
\begin{enumerate}
\item Participants use FROST key generation such that, for each $1 \leq i \leq n$, the $i^{th}$ participant obtains the total verification FROST key $Y$, secret signing key share\footnote{The secret share $y_i$ is denoted $s_i$ in the original FROST paper; however, we use $s_i$ for signature data to maintain consistency with previous ring signature publications.}  $y_i$, and public verification key share $Y_i$.
\item For each $i \in [n]$, the $i^{th}$ participant computes $Z_k = z_k G$ for each $k \in [d-1]$. These are called the \textit{auxilliary keys}.
\item Compute the \textit{main linking tag share} $\mathfrak{T}_i = y_i H_{\texttt{base}}(Y)$ and the \textit{auxilliary linking tags} $\mathfrak{D}_k = z_k \cdot H_{\texttt{base}}(Y)$ for $k \in [d-1]$.
\item The key $Y \in \tvk$ is called the \textit{linking key}. Set the following.

\vspace{-2em}

\begin{align*}
    \sk_i &= (y_i, z_1, \ldots, z_{d-1}), \quad \vk_i = (Y_i, Z_1, \ldots, Z_{d-1}), \\
    \tvk &= (Y, Z_1, \ldots, Z_{d-1}), \quad \text{and} \quad \lt_i = (\mathfrak{T}_i, \mathfrak{D}_1, \ldots, \mathfrak{D}_{d-1}).
\end{align*}

\vspace{-1em}


% \begin{align*}
% \sk_i &= (y_i, z_1, \ldots, z_{d-1}), \\
% \vk_i &= (Y_i, Z_1, \ldots, Z_{d-1}), \\
% \tvk &= (Y, Z_1, \ldots, Z_{d-1}),\text{ and}\\
% \lt_i &= (\mathfrak{T}_i, \mathfrak{D}_1, \ldots, \mathfrak{D}_{d-1})
% \end{align*}


\end{enumerate}
At the end of this process, each signer has learned their total verification key $\tvk$ for the group, secret key shares $\sk_i$, public key shares $\vk_i$, and linking tag share $(\tvk, \vk_i, \lt_i, \sk_i)$. 
% We call these participants \textit{signers}.


\item $\sign(\msg, \ring, \VK,  \sk, (\tlt, \texttt{com}, d, e)) \to \psig$. 
A non-interactive PPT algorithm individually carried out by signers. Signers are expected to interactively decide upon a message $\msg$, a ring $\ring$, a signers' coalition of public verification key shares $\VK^\prime$, a total linking tag $\tlt$, and a hash table $\texttt{com}$ by secure side channel with authentication in a pre-processing step before executing $\sign$; see $\preproc$ below in \cref{sec:extensions}. Input a message $\msg$, a ring $\ring = (\tvk_1, \ldots, \tvk_m)$, a signers' coalition of public verification key shares $\VK^\prime = (\vk_i^\prime)_{i=1}^{r}$, a secret key $\sk$, and auxiliary data $(\tlt, \texttt{com}, d, e)$, where $\tlt$ is a total linking tag, $\com = \left\{(\vk_i, (D_i, E_i, D_i^\prime, E_i^\prime))\right\}_{i=1}^{r}$ is a hash table with keys $\vk_i \in \VK$ and values $(D_i, E_i, D^\prime_i, E^\prime_i) \in \G^4$, and $d, e \in \Zq$ are secret scalars.

The signer does the following.
\begin{enumerate}
\item  Find the index $j^* \in [m]$ such that the ring member $\tvk_{j^*} \in \ring$ is the total verification key. If no such index exists, output a distinct failure symbol and terminate.
\item Find the index $i^* \in [r]$ such that $\sk$ corresponds to $\vk_{i^*} \in \VK$. If no such index exists, output a distinct failure symbol and terminate.
\item Parse:
\begin{enumerate}
\item $(y_{i^*}, z_1, \ldots, z_{d-1}) := \sk$, 
\item $(Y_i, Z_{i,1}, \ldots, Z_{i,d-1}) := \vk_i$ for $i \in [r]$,
\item $\left\{(\vk_i, (D_i, E_i, D_i^\prime, E_i^\prime))\right\}_{i=1}^{r} := \texttt{com}$, 
\item $(Y^\prime_j, Z_{j,1}^\prime, \ldots, Z_{j,d-1}^\prime) := \tvk_j$ for $j \in [m]$, and
\item $(\mathfrak{T}, \mathfrak{D}_1, \ldots, \mathfrak{D}_{d-1}) := \tlt$.
\end{enumerate}

\item If there exists any $j \in [m]$, $k \in [d-1]$ such that $Z_{j,k} \neq Z^\prime_{j,k}$, output $\bot$ and terminate.


\item Compute:
\begin{enumerate}
\item the point hash $\widehat{Y}_{j^*} = H_{\texttt{base}}(Y_{j^*})$.
\item a seed\footnote{A functionally equivalent implementation uses an extendable output function $\texttt{xof}$ to extract $\underline{s}$ directly, bringing efficiency gains and reducing the risk of implementation errors.} $\gamma \leftarrow H_{\seed}(\VK \mid \mid \widehat{Y}_{j^*} \mid \mid \ring \mid \mid \tlt \mid \mid \msg \mid \mid \texttt{com})$, 
\item the Lagrange coefficients $\lambda_i = \prod_{i^\prime \neq i} \frac{i}{i^\prime-i} (\text{mod }q)$ for each $i \in [r] = \left\{1,2,\ldots,r\right\}$.
\item FROST coefficients for $i \in [r]$, $\rho_i = H_{\FROST,i}(\msg \mid \mid \widehat{Y}_{j^*} \mid \mid \ring \mid \mid \VK \mid \mid \LT \mid \mid \com)$,



\item FROST nonces $F_i = D_i + \rho_i E_i$ for $i \in [r]$,
\item FROST-like nonces $F^\prime_i = D^\prime_i + \rho_i E^\prime_i$ for $i \in [r]$,

\item starting nonces $L_{j^*} = \sum_{i=1}^{r} F_i$ and $R_{j^*} = \sum_{i=1}^{r} F^\prime_i$, and
\item starting signature challenge

\vspace{-2em}

\begin{align*}
    c_{j^*+1} &= H_{\texttt{ch}}\signaturequerystar, \\
    &\text{where } j^* = m \text{ implies that } c_{m+1} \equiv c_1
\end{align*}

% \[c_{j^*+1} = H_{\texttt{ch}}\signaturequerystar, \text{ where } j^* = m \Rightarrow c_{m+1} \equiv c_1\] 
% where we identify $c_{m+1} \equiv c_1$ in the case that $j^* = m$.

\vspace{-1em}

\end{enumerate}

\item Sample $(s_j)_{j \neq j^*} \leftarrow F_{\texttt{PRNG}}(\gamma)$.


\item\label{step:commonstuff} Compute:
\begin{enumerate}

\item the point hashes of ring members' leading keys $\widehat{Y}_j = H_{\texttt{base}}(Y_j^\prime)$.

\item the aggregation coefficients

\vspace{-2em}

\begin{align*}
\mu_{Y} =& H_{\lt}^*(\ring  \mid \mid \tlt \mid \mid \underline{\widehat{Y}}), \quad \text{and} \quad \mu_{k} = H_{\lt,k}(\ring \mid \mid \tlt \mid \mid \underline{\widehat{Y}})\text{ for each }k \in [d-1],
\end{align*}

\vspace{-1em}




\item the aggregated linking tag
$\mathfrak{W} = \mu_{Y} \mathfrak{T} + \sum_{k=1}^{d-1} \mu_{k} \mathfrak{D}_k$,



\item for each $j \in [m]$, the $j^{th}$ aggregated ring member $W_j = \mu_Y Y_j^\prime + \sum_{k=1}^{d-1} \mu_k Z_{j,k}^\prime$,




\item For $j^* < j \leq m$, compute the nonces and signature challenges:

\vspace{-2em}

\begin{align*}
L_j =& s_j G + c_j W_j \quad \text{and} \quad R_j = s_j \widehat{Y}_j + c_j \mathfrak{W} \\
c_{j+1} =& H_{\texttt{ch}}\signaturequery % LINE 269 IN KAYABA'S RINGCT CODE
\end{align*}

\vspace{-1em}

\item Set $c_1 = c_{m+1}$ and, for $1 \leq j < j^*$, compute the nonces and signature challenges as in the previous step.

\end{enumerate}

\item Set $s_{j^*, i^*} = d + \rho_{i^*} e + \lambda_{i^*} \cdot c_{j^*} \cdot w_{i^*}$.

\item Output $\psig = (i^*, \lt_{i^*}, c_1, s_1, \ldots, s_{j^*-1}, s_{j^*, i^*}, s_{j^*+1}, \ldots s_m)$.
\end{enumerate}

\item $\combine(\msg, \ring, \psigs) \to \sig$. Input a message $\msg$, a ring $\ring$, and signature shares $\psig_1, \ldots, \psig_r$, and output a ring signature $\sig$. Do the following.
\begin{enumerate}
\item Parse $(\vk_1, \ldots, \vk_r) := \VK$, $(Y_i, Z_{i,1}, \ldots, Z_{i,d-1}) := \vk_i$ for $i \in [r]$, and $Y := \tvk$. Parse $(\tvk_1, \ldots, \tvk_m) := \ring$ and find the index $1 \leq j^* \leq m$ in $\ring$ such that $Y  \tvk_{j^*}$. Otherwise, output a distinct failure symbol and terminate.

\item Parse each $(i^\prime_i, \lt_i, c_{i,1}, (s_{i,j})_{j=1}^{m}) := \psig_i$ for each $i \in [r]$. 

\item If there exists indices $i_1 \neq i_2$ such that $\lt_{i_1} = \lt_{i_2}$, output a distinct failure symbol and terminate. 

\item Otherwise, if there exists indices $i_1 \neq i_2$ any signature challenges mismatch, $c_{i_1,1} \neq c_{i_2, 1}$, output a distinct failure symbol and terminate.

\item Otherwise, for any $1 \leq i_1, i_2 \leq r$, $1 \leq j \leq m$, if $j \neq j^*$ and $s_{i_1,j} \neq s_{i_2, j}$, output a distinct failure symbol and terminate.

\item Otherwise, set $c_1 = c_{1,1}$, set $\widehat{s}_j = s_j$ for each $j \neq j^*$, set $\widehat{s}_{j^*} = \sum_{i=1}^{r} s_{i,j^*}$, and output the signature $\sig = (c_1, (\widehat{s})_{j=1}^{m}, \tlt)$
\end{enumerate}

\item $\verify(\msg, \ring, \sig) \to b$. Input a message $\msg$, a ring $\ring = (\tvk_1, \ldots, \tvk_m)$, and a signature $\sig$. Output a bit. Works as follows.
\begin{enumerate}
\item Parse $(c_1, s_1, \ldots, s_m, \mathfrak{T}, \mathfrak{D}_1, \ldots, \mathfrak{D}_{d-1}) := \sig$. 
\item If $\mathfrak{T} = 0$ or any $\mathfrak{D}_{d-1} = 0$, output $0$ and terminate.
\item Using $j^* = 1$, execute step \cref{step:commonstuff} in $\sign$.
\item If $c_1 = c_{m+1}$, output $1$ and terminate; otherwise output $0$ and terminate.
\end{enumerate}


\item $\link(\sig, \sig^\prime) \to b$. Do the following.
\begin{enumerate}
\item Parse the following.
\begin{enumerate}
\item $(c_1, s_1, \ldots, s_m, \tlt) := \sig$, $(c_1^\prime, s_1^\prime, \ldots, s_m^\prime, \tlt^\prime) := \sig^\prime$,
\item $(\mathfrak{T}, \mathfrak{D}_1, \ldots, \mathfrak{D}_{d-1}) := \lt$,  $(\mathfrak{T}^\prime, \mathfrak{D}_1^\prime, \ldots, \mathfrak{D}_{d-1}^\prime) := \lt^\prime$. 
\end{enumerate}
\item Output a bit indicating whether $\mathfrak{T} = \mathfrak{T}^\prime$.
\end{enumerate} 


\end{enumerate}
\end{definition}

Beware that signature shares leak information, like the true signer's ring index. Executing $\verifyshare$ or $\combine$ can only be safely done with other signers.

\vspace{-1.5em}

\subsection{Extensions and Additional Algorithms}\label{sec:extensions}

\vspace{-1em}

% (\cref{def:frostlass})
FROSTLASS can be made verifiable as described in \cref{sec:definitions} with a $\verifyshare$ algorithm as follows.
\vspace{-1em}

\begin{itemize}
\item $\verifyshare(\msg, \ring, \VK, \psig, \tlt, \texttt{com}) \to b$ inputs some $\msg$,  $\ring = (\tvk_1, \ldots, \tvk_m)$,
signers' coalition of key shares $\VK = (\vk_i)_{i=1}^{r}$, a signature share $\psig=(i^*, \lt, c_1, s_1, \ldots, s_m)$, a total linking tag $\tlt$, and a hash table $\texttt{com}$, and outputs a bit. Do the following.
\begin{enumerate}
\item Set $j^* = 1$.
\item Carry out step c of $\sign$.
\item Parse $(i^*, \lt, c_1, s_1, \ldots, s_m) := \psig$.
\item Carry out step d of $\sign$.
\item Carry out step e of $\sign$. If any $s_j$ mismatch their corresponding element in $\psig$, output $0$ and terminate.
\item Carry out step f of $\sign$, to obtain each $c_j^\prime$.
\item If $c_1 \neq c_1^\prime$, or $s_{j^*, i^*}G \neq \lambda_{i^*} c_{i^*} Y_{i^*}$, or $s_{j^*, i^*}\widehat{Y}_{j^*} \neq \lambda_{i^*}c_{j^*} \mathfrak{W}$, output $0$ and terminate.
\item Otherwise, output $1$ and terminate.
\end{enumerate}
\end{itemize}

\vspace{-0.5em}

FROSTLASS also admits a pre-processing step wherein participants may commit to their auxiliary signing data ahead of time and compute their total linking tag $\tlt$, which works as follows.

\vspace{-1em}

\begin{itemize}
\item $\preproc(\tvk, \VK, \SK) \to (\lt,  \texttt{com})$. An interactive PPT algorithm required to execute $\sign$ and $\verifyshare$, and which requires some $r \geq 1$ participants and a digital signature scheme $\Pi_{DSS}$ as a subroutine. Input total verification key $\tvk$, signers' coalition of public verification key shares $\VK = (\vk_i)_{i=1}^{r}$, and secret signing key shares $\SK = (\sk_i)_{i=1}^{r}$. Output a hash table $\texttt{com}$. 
 Participants do the following. 
\begin{enumerate}
\item Parse $(\mathfrak{T}_i, \underline{\mathfrak{D}}^{(i)}) := \lt_i$. If any $\underline{\mathfrak{D}}^{(i)} \neq \underline{\mathfrak{D}}^{(i^\prime)}$, output $\bot$ and terminate. 
\item Otherwise, carry out step d.ii and d.iii from $\sign$ to compute the Lagrange coefficients $\lambda_i$ and the linking tag $\mathfrak{T} = \sum_i \mathfrak{T}_i$.
\item Compute the point hash of the linking key $\widehat{Y} = H_{\texttt{base}}(Y)$.
\item For each $i \in [r]$, the $i^{th}$ participant samples $(d_i, e_i) \in \Zq^2$ and computes the following:

\vspace{-1em}

$$D_i = d_i G, \quad D_i^\prime = d_i \widehat{Y}, \quad
E_i = e_i G, \quad \text{ and} \quad
E_i^\prime = e_i \widehat{Y}.$$

% \begin{align*}
% D_i &= d_i G, & D_i^\prime &= d_i \widehat{Y}, \\
% E_i &= e_i G,\text{ and} &
% E_i^\prime &= e_i \widehat{Y}.
% \end{align*}
\item The $i^{th}$ participant sends $(\lt_i, D_i, E_i, D^\prime_i, E^\prime_i)$ in an authenticated all-to-all broadcast to the other signers\footnote{Equivalently, all users may send their commitment points to a single member, who may then broadcast $\texttt{com}$ back to all other users after executing step 3 of \texttt{PreProc}}.

\item After using $\Pi_{DSS}$ to verify this communication, participants set $\texttt{com}$ to be a hash table with keys $\vk_i$ and values $\texttt{com}[\vk_i] = (D_i, E_i, D^\prime_i, E^\prime_i)$.
\end{enumerate}
\end{itemize}


FROSTLASS also only links ring signatures according to whether the linking tags $\mathfrak{T}$ match, where $\mathfrak{T}$ is a collision-resistant image of the link of the signing key. That is, linking is not bound to the message, the other keys $Z_k$ of the signing key, or the ring. Variations of this scheme binding linking to more data can provide a hierarchical expansion of linkability; this may be a fruitful area of further research.

\vspace{-1.5em}

\subsection{Concrete Instantiation}\label{sec:concrete_instantiation}

\vspace{-1em}

To concretely implement random oracles in practice, we employ hash functions $H_{\G}: \bitstrings \to \G$, $H_{\Zq}:\bitstrings \to \Zq$, and $H_{\secpar}:\bitstrings \to \left\{0,1\right\}^\secpar$ with distinct domain separating tags $\dst_{\texttt{label}} \in \bitstrings$. For example, we concretely instantiate $H_{\texttt{base}}$ by mapping $x \mapsto H_{\G}(\dst_{\texttt{base}} \mid \mid x)$. Note that we can avoid domain separating tags and associated implementation errors without losing efficiency by using an extendable output function $\texttt{xof}$ instead of hash functions throughout, extracting $(\mu_Y, \mu_1, \ldots, \mu_{d-1}) \leftarrow \texttt{xof}(\vk_{j^*})$ directly with one function call.

\vspace{-1.5em}

\subsection{Variations From Older Versions of CLSAG and the Rust Implementation}\label{sec:variations_from_implem}

\vspace{-1em}

\cref{def:frostlass} varies from older versions of CLSAG and the Rust implementation at \cite{SeraiRepo} in a few ways.

\vspace{-1em}

\begin{itemize}
\item We strictly follow the ``hash the complete transcript'' paradigm to prevent malleability in \cref{def:frostlass}. This causes some significant variations from previous versions of CLSAG and the Rust implementation; much more data is included in our hash pre-images.
\begin{itemize} 
\item For example, we include the point hashes of the ring members $\underline{\widehat{Y}}$ when computing aggregation coefficients in g.ii of $\sign$. This prevents an adversary from attempting to pick some aggregation coefficients before selecting a ring. 
\item Similarly, we also include the aggregated key image $\mathfrak{W}$ in the preimage of every signature challenge computation. This prevents an adversary from attempting to pick a signature challenge before deciding upon an aggregated key image. 
\end{itemize}
This binding prevents malleability. We see no obvious way to violate any of our security properties without taking such care, but we do so as a matter of good practice for the formal definition of the scheme. Practical implementations do not need to be quite so stringent. For example, although CLSAG signatures do not usually compute $c_{j+1}$ with the total linking tag $\tlt$ included in the pre-image, the most notable application of CLSAG signatures (the Monero cryptocurrency) includes these data in the message being signed. By including these data in $\msg$, those applications essentially enforce (some of) the ``include all data in all hashes'' paradigm.

\item The order of our computations in \cref{def:frostlass} is not necessarily faithful to the order of computations in \cite{SeraiRepo}.  Our description in \cref{def:frostlass} is ordered in a way which makes cross-referencing within this document easier, improving the readability of our description of $\verify$ and $\verifyshare$ substantially. None of our variations from \cite{SeraiRepo} cause security problems and are rather superficial.

\item All hashing in \cite{SeraiRepo} is deterministically computed from transcript data. The approach in this repo largely follows the ``hash the complete transcript'' paradigm. Indeed, the Rust implementation appends data to running transcripts constructed in a canonical way.  However, this transcript is pruned whenever data can be deterministically and verifiably computed from the state of the transcript at some point. For example, computing $x = H(\msg)$, $y = H(0 \mid \mid x)$, and $z = H(1 \mid \mid x)$ is safe; we do not need to compute $z = H(1 \mid \mid y \mid \mid x)$. This approach is consistent with, e.g.\ approaches in IETF standards like RFC 9591.


\end{itemize}



\vspace{-2em}

\section{FROSTLASS Security}

\vspace{-1em}


Correctness and linkability depend on the following lemmata, wherein we intentionally conflate linking tags $\mathfrak{T}$ with a function mapping a linking key to its linking tag. Recalling $H_{\G}$ was a hash function modeled as a random oracle (see \cref{sec:concrete_instantiation}), this lemma establishes that, as a corollary, $\mathfrak{T}$ is indistinguishable from a random oracle.

\vspace{-1em}

\begin{lemma}\label{lem:link_tags_are_oracles}
Let  $\dst \in \bitstrings$ be a domain separating tag, let $\theta:\G \to \G$ be any function, let $\phi: \Zq \times \G \to \G$ be the function defined by mapping $(x, Y) \mapsto x \cdot \theta(Y)$, and let $t_{\texttt{scmul}}$ denote the time it takes to multiply a point in $\G$ by a scalar in $\Zq$. If some PPT $(t,\epsilon)$ algorithm $\mathcal{A}$ (or $\mathcal{B}$, respectively) is a $\kappa$-distinguisher for $\phi$ (or $\theta$, respectively) under definition \cref{def:distinguisher}, then there exists a PPT $(t^\prime, \epsilon^\prime)$ algorithm $\mathcal{A}^\prime$ (or $\mathcal{B}^\prime$, respectively) which is a $\kappa$-distinguisher for $\theta$ (or $\phi$, respectively).
\end{lemma}
\begin{proof}
Assume the algorithm $\mathcal{A}$ can distinguish $\phi$ from a random oracle in \cref{def:distinguisher}. We build a $\mathcal{A}^\prime$ to distinguish $\theta$ as follows.

\vspace{-1em}

\begin{enumerate}
\item $\mathcal{A}^\prime$ is granted oracle access to $\mathcal{O}^\prime_b:\G \to \G$.
\item $\mathcal{A}^\prime$ runs $\mathcal{A}$ as a subroutine, handling oracle queries as follows. When $\mathcal{A}$ sends some query $(x, Y) \in \Zq \times \G$, $\mathcal{A}^\prime$ computes $Y^\prime \leftarrow \mathcal{O}^\prime_b(Y)$, sets $Z = xY^\prime$, and responds with $Z$.
\item When $\mathcal{A}$ outputs $b^\prime$, $\mathcal{A}^\prime$ outputs $b^\prime$.
\end{enumerate}

\vspace{-1em}

It is clear that this $\mathcal{A}^\prime$ correctly plays the $\kappa$-random oracle distinguisher game for $\theta$, succeeds if and only if $\mathcal{A}$ succeeds at distinguishing $\phi$, and takes only the additional time to compute $xY^\prime$ from $x$ and $Y^\prime$, i.e.\ a single scalar multiplication.

Likewise, assume $\mathcal{B}$ can distinguish $\theta$ from a random oracle. We build $\mathcal{B}^\prime$ similarly.

\vspace{-1em}

\begin{enumerate}
\item $\mathcal{B}^\prime$ is granted oracle access to $\mathcal{O}^\prime_b:\Zq \times \G \to \G$.
\item $\mathcal{B}^\prime$ runs $\mathcal{B}$ as a subroutine, handling oracle queries as follows. When $\mathcal{B}$ sends some query $Y \in \G$, $\mathcal{B}^\prime$ samples $x \sample \Zq$, computes $Y^\prime \leftarrow \mathcal{O}^\prime_b(x, Y)$, sets $Z = x^{-1}Y^\prime$, and responds with $Z$.
\item When $\mathcal{B}$ outputs $b^\prime$, $\mathcal{B}^\prime$ outputs $b^\prime$.
\end{enumerate}

\vspace{-1em}

It is also clear that this $\mathcal{B}^\prime$ correctly plays the $\kappa$-random oracle distinguisher game for $\phi$, succeeds if and only if $\mathcal{B}$ succeeds at distinguishing $\theta$, and takes additional time for sampling, inverting an element from $\Zq$, and multiplying a point by a scalar, i.e. extra time $t_{\texttt{sample}} + t_{\texttt{inv}} + t_{\texttt{scmul}}$.
\end{proof}

\vspace{-1em}

\begin{cor}\label{cor:key_images_are_random_oracles}
Let $r \geq 1$. Each of the maps $\mathfrak{T}:\Zq \to \G$ and $\mathfrak{T}_i:\Zq^r \times\G\to\G$ defined by mapping $y \mapsto yH_{\texttt{base}}(yG)$ and $(\underline{y}, Y) \mapsto y_i H_{\texttt{base}}(Y)$ are indistinguishable from random oracles.
\end{cor}

\vspace{-1.5em}

\subsection{Correctness}

\vspace{-0.5em}

\begin{theorem}
FROSTLASS is a correct LTM scheme under \cref{def:correctness}.
\end{theorem}
\begin{proof}
In event $E_2$, consider the ring signature shares $\psig_i^\prime$, $\psig_i^{\prime \prime}$, and $\psig_i^*$. These have some corresponding indices $j^\prime, j^{\prime \prime}$, and $j^*$, respectively, and we write these ring signature shares as follows.
\begin{align*}
\forall i \in \left[\left|\VK^\prime\right|\right], \psig_i^\prime =& (i, c_1^\prime, s_1^\prime, \ldots, s_{j^*-1}^\prime, s_{j^*, i}^\prime, s_{j^*+1}^\prime, \ldots, s_m^\prime),  \\
\forall i \in \left[\left|\VK^{\prime\prime}\right|\right], \psig_i^\prime =& (i, c_1^\prime, s_1^\prime, \ldots, s_{j^*-1}^{\prime\prime}, s_{j^*, i}^{\prime\prime}, s_{j^*+1}^{\prime\prime}, \ldots, s_m^{\prime\prime}),  \\
\forall i \in \left[\left|\VK^*\right|\right], \psig_i^* =& (i, c_1^*, s_1^*, \ldots, s_{j^*-1}^*, s_{j^*, i}^*, s_{j^*+1}^*, \ldots, s_m^*)
\end{align*}  

Each signer with index $i \in \left[\left|\VK^\prime\right|\right]$, computes the same seed, say $\gamma^\prime$ in event $E_1$, so $(s_j^\prime)_{j \neq j^{\prime}, i}$ is identical in each $\psig_i^\prime$, where $j^\prime$ is the ring index of the true signer for $\psig_i^\prime$. Similarly, each signer with index $i \in \left[\left|\VK^{\prime\prime}\right|\right]$ computes the same seed, say $\gamma^{\prime \prime}$, and $(s_j^{\prime \prime})_{j \neq j^{\prime \prime}, i}$ is identical in each $\psig_i^{\prime \prime}$, where $j^{\prime \prime}$ is the ring index of the true signer for $\psig_i^{\prime \prime}$. In event $E_1^*$, each signer with index $i \in \left[\left|\VK^{**}\right|\right]$ 
compute the same seed $\gamma^*$, and $(s_j^*)_{j \neq j^*, i}$ is identical in each $\psig_i^*$, where $j^*$ is the index of the true signer of $\psig_i^*$. Moreover, these ring signature shares were all output from honest executions of $\sign$. 

To show $\mathbb{P}[E_2] = 1$, it is sufficient to demonstrate that each $\psig_i^\prime$ passes $\verifyshare$ in $E_1$. Indeed, the ring signature shares $\psig_i^{\prime \prime}$ and $\psig_i^*$ are shown to be valid in a similar way, \textit{mutatis mutandis}. 

In $E_1$, the points $L_{j^\prime}^\prime = \sum_i F_i$ and $R_{j^\prime}^\prime = \sum_i F_i^\prime$ are computed with the starting challenge $c_{j^\prime+1}$.

Then, for $j^* < j \leq m$, the following computations take place.
\begin{align*}
L_j^\prime =& s_j^\prime G + c_j^\prime W_j^\prime, \quad 
R_j^\prime = s_j^\prime \widehat{Y}_j^\prime + c_j^\prime \mathfrak{W} \\
c_{j+1} =& H_{\texttt{ch}}(\texttt{dst}_{j} \mid \mid \ring \mid \mid \tlt \mid \mid \underline{\widehat{Y}} \mid \mid \mathfrak{W} \mid \mid \underline{W} \mid \mid \underline{\mu} \mid \mid L_{j} \mid \mid R_{j} \mid \mid \msg^\prime)
\end{align*}
Then the value $c_1 = c_{m+1}$ is set and, for $1 \leq j \leq j^*$, the same computations for $L_j^\prime, R_j^\prime, c_j^\prime$ take place. Lastly, each $s_{j^\prime, i}^\prime = d_i^\prime + \rho_i^\prime e_i^\prime + \lambda_i^\prime c_{j^\prime}^\prime y_i^\prime$ for the random scalars $d_i^\prime, e_i^\prime$, the corresponding aggregation coefficient $\rho_i^\prime$, Lagrange interpolation coefficient $\lambda_i^\prime$, and secret signing key share $y_i^\prime$.
Thus, in $E_1$, the verifier computes $\gamma^\prime$ the same as the signer, and so samples $(s_j^\prime)_{j\neq j^\prime,i}$ identically to all the signers. Moreover, for each $1 \leq j \leq m^\prime$, 
the signature nonce points satisfy $L_j^\prime = s_j^\prime G + c_j^\prime W_j^\prime$, $R_j^\prime = s_j^\prime \widehat{Y}_j^\prime + c_j^\prime \mathfrak{W}$, and the signature challenges satisfy the verification equations, except $j=j^\prime$. 


In event $E_3$, we have the following combined signatures.
\begin{align*}
\sig^\prime &= (c_1^\prime, s_1^\prime, \ldots, s_{j^\prime - 1}^\prime, \sum_i s_{j^\prime, i}^\prime, s_{j^\prime + 1}^\prime, \ldots, s_m^\prime, \lt^\prime) \\
\sig^{\prime \prime} &= (c_1^{\prime \prime}, s_1^{\prime \prime}, \ldots, s_{j^{\prime \prime} - 1}^{\prime \prime}, \sum_i s_{j^{\prime \prime}, i}^{\prime \prime}, s_{j^{\prime \prime} + 1}^{\prime \prime}, \ldots, s_m^{\prime \prime}, \lt^{\prime \prime}) \\
\sig^* &= (c_1^*, s_1^*, \ldots, s_{j^* - 1}^*, \sum_i s_{j^*, i}^*, s_{j^* + 1}^*, \ldots, s_m^*, \lt^*) 
\end{align*}

\vspace{-1em}
Moreover, the aggregation coefficients, aggregated ring members, point hashes of ring members' leading keys, and the seed are all computed exactly as in $\sign$ and $\verifyshare$. So, by construction, $c_1 = c_{m+1}$ and the circle of hashes pass verification.

Lastly, consider events $E_4$, $E_5$, and $E_6$. $\link$ merely compares the linking tags. Moreover, as $\link$ is a check for equality of linking tags, it is necessarily commutative.
In event $E_5$, $\sig^\prime$ and $\sig^{\prime \prime}$ are both computed from superthreshold subsets of $\VK$ with the same corresponding $\lt$, and so have identical linking tags $\mathfrak{T}$. 

In event $E_6$, the signatures are computed for distinct $\tvk \neq \tvk^\prime$. By  \cref{cor:key_images_are_random_oracles}, $\mathfrak{T}(\tvk) \neq \mathfrak{T}(\tvk^\prime)$, so $\link(\sig^\prime, \sig^*) = \link(\sig^*, \sig^{\prime \prime}) = 0$ except with negligible probability.
\end{proof}

\vspace{-2em}

\subsection{Strong Unforgeability}

\vspace{-0.5em}

\begin{theorem}\label{thm:suf}
Let $\kappa_{\texttt{ch}}, \kappa_{\texttt{key}}, n_{\texttt{key}} \geq 1$ be integer parameters. For every PPT $(t, \epsilon)$-forger $\mathcal{A}$ as described in \cref{def:suf}, there exists a PPT $(t^\prime, \epsilon^\prime)$-player of the $(n_{\texttt{key}}\kappa_{\texttt{key}} - 1)$-OMDL game such that $t^\prime \in O(2t)$ and $\epsilon^\prime \in O(\frac{\epsilon^2}{\kappa_{\texttt{ch}}})$.
\end{theorem}

\vspace{-1em}

\begin{proof}
We solve the $\kappa$-OMDL game by constructing a tower of algorithms $\mathcal{A}_4 \rightarrow \mathcal{A}_3 \rightarrow \mathcal{A}_2 \rightarrow \mathcal{A}_1$, where $\mathcal{A}_1 = \mathcal{A}$ is a forger, $\mathcal{A}_2$ is a simulator of the unforgeability challenger for $\mathcal{A}_1$, $\mathcal{A}_3 = \texttt{Fork}_{\mathcal{A}_2}$ is the forking algorithm of \cref{def:general_forking_algorithm}, and $\mathcal{A}_4 = \mathcal{A}^\prime$ plays the $\kappa$-OMDL game. These arrows indicate $\mathcal{A}_4$ runs $\mathcal{A}_3$ as a subroutine, and so on. We discuss these in order beginning with $\mathcal{A}_1$, the forger.

\textbf{The forger.} Let $\mathcal{A}_1$ be a $(t_1, \epsilon_1)$-algorithm which is an LTM strong forger of FROSTLASS as described in \cref{def:suf} and runs with some random tape $\tau_{\mathcal{A}_1}$. $\mathcal{A}_1$ has access to the oracles $\keyOracle$, $\corruptionOracle$, and $\signingOracle$ from \cref{def:common_setup} via \cref{def:suf}, 
and all the random oracles $H_{\texttt{label}}$ with $\texttt{label} \in \left\{\texttt{base}, \texttt{seed}, (\texttt{FROST}, i), (\texttt{kb}, k), \texttt{ch}\right\}$ for $i \in \mathbb{N}$ and $k \in [d-1]$ from \cref{def:frostlass}. 

\textbf{Wrap the forger.}  We first wrap $\mathcal{A}_1$ in an algorithm $\mathcal{A}_2$. This $\mathcal{A}_2$ simulates the forgery challenger for $\mathcal{A}_1$ and is compatible with \cref{def:general_forking_algorithm}, and is a helper algorithm for playing \cref{def:omdl} which requires oracle access; we denote the oracles of \cref{def:omdl} with $\keyOracle^*$ and $\corruptionOracle^*$ to prevent confusion. $\mathcal{A}_2$ works as follows. 

\vspace{-1em}

\begin{enumerate}
\item Initialize empty tables $T_{\texttt{label}}$ for $\texttt{label} \in \left\{\texttt{base}, \texttt{seed}, (\texttt{FROST},i), (\lt, k), \texttt{ch}, \texttt{DL}\right\}$.
\item Run $\mathcal{A}_1$ as a subroutine. As a simulator of the game of \cref{def:suf}, $\mathcal{A}_2$ handles all oracle queries made by $\mathcal{A}_1$ as follows.
\begin{enumerate}
\item For $\texttt{label} \in \left\{\texttt{seed}, (\texttt{FROST},i), (\lt, y), (\lt, k) \mid i \in [n_{\texttt{key}}], k \in [d-1]\right\}$, when $\mathcal{A}_1$ queries $H_{\texttt{label}}$, $\mathcal{A}_3$ simulates responses using its own internal random tape, resampling in the event of a collision, and storing query-response pairs as key-value pairs in hash tables $T_{\texttt{label}}$ to maintain consistency with later queries. We assume handling these queries requires no other oracle queries, takes negligible time, and certainly succeeds. These simulations are indistinguishable from real oracles, as they are directly simulated from the random tape of $\mathcal{A}_2$.


\item When $\mathcal{A}_1$ makes some $\texttt{query}$ to $H_{\texttt{ch}}$ and $\texttt{query} \notin T_{\texttt{ch}}$, $\mathcal{A}_2$ computes $i = \left|T_{\texttt{ch}}\right|+1$, finds $h_i \in \underline{h}$, stores $T_{\texttt{ch}}[\texttt{query}] = (i, h_i)$, and responds with $h_i$.  We assume handling these queries requires no other oracle queries, takes negligible time, and succeeds with certainty.

\item When $\mathcal{A}_1$ makes some $\texttt{query}$ to $H_{\texttt{base}}$, $\mathcal{A}_2$ checks if $\texttt{query} \notin T_{\texttt{base}}$. If so, $\mathcal{A}_2$ samples $\alpha \leftarrow \Zq$, resampling in the case of a collision, and sets $T_{\texttt{base}}[\texttt{query}] = \alpha$. The response is computed in two cases.
\begin{enumerate}
\item If $\texttt{query} \notin \mathbb{G}$, then $\mathcal{A}_2$ samples $Y \leftarrow \mathbb{G}$ and responds with $\alpha Y$.
\item Otherwise, $\mathcal{A}_2$ parses $Y \leftarrow \texttt{query}$, and responds with $\alpha Y$.
\end{enumerate}
This query requires no further oracle access, takes the time to sample $\alpha \sample \Zq$, possibly the time it takes to sample $Y \in \G$, and the time it takes to compute $\alpha Y$, a scalar multiplication of a point. Thus, this query takes time at most $t_{\texttt{base}} \approx t_{q} + t_\mathbb{G} + t_{\texttt{scmul}}$, where $t_q$ is the time it takes to sample $\alpha$, $t_\mathbb{G}$ is the time it takes to sample $Y \in \mathbb{G}$, and $t_{\texttt{scmul}}$ is the time it takes to compute $\alpha Y$. This query certainly succeeds.


\item When $\mathcal{A}_1$ queries $\keyOracle$ with some pair $(n,r)$, $\mathcal{A}_2$ does the following.
\begin{enumerate}
\item If $r \notin [n]$, output a distinct failure symbol and terminate.
\item Otherwise, for each $i \in [n]$, make a query $Y_i \leftarrow \keyOracle^*(\ast)$ from \cref{def:omdl}.
\item Compute $Y = \sum_{i \in [n]} Y_i$.
\item Sample $(z_1, \ldots, z_{d-1}) \leftarrow \Zq^{d-1}$.
\item Compute each $Z_k = z_k G$ and store $T_{\texttt{DL}}[Z_k] = z_k$.
\item Simulate a query made to $H_{\texttt{base}}$ by $\mathcal{A}_1$, $\widehat{Y} = H_{\texttt{base}}(Y)$.
\item Retrieve $\alpha = T_{\texttt{base}}[Y]$; this table entry is non-empty with certainty due to the previous step.
\item Set $\mathfrak{T} = \alpha Y$, $\mathfrak{T}_i = \alpha Y_i$, and each $\mathfrak{D}_k = \alpha Z_k$ for each $i \in [n]$ and each $k \in [d-1]$.

\item Set $\tvk = (Y, Z_1, \ldots, Z_{d-1})$, $\lt = (\mathfrak{T}, \mathfrak{D}_1, \ldots, \mathfrak{D}_{d-1})$, each $\vk_i = (Y_i, Z_1, \ldots, Z_{d-1})$, and each $\lt_i = (\mathfrak{T}_i, \mathfrak{D}_1, \ldots, \mathfrak{D}_{d-1})$. 
\item Store $T_{\lt}[\vk_i] = \lt_i$ and $T_{\tlt}[\vk] = \tlt$. 
\item Respond with $(\tvk, \VK)$. 
\end{enumerate}
Handling one $\keyOracle$ query takes $n$ queries to $\keyOracle^*$ and one query to $H_{\texttt{base}}$, $n^2$ sums of points from $\G$, $(d-1)$ samples from $\Zq$, and $2d+1$ scalar multiplications against points. This query takes time at most $t_{\texttt{key}} \approx nt_{\texttt{key}}^* + n^2 t_+ + (d-1)t_{q} + (1+2d)t_{\texttt{scmul}} + t_{\texttt{base}}$, where $t_{\texttt{key}}^*$ is the time it takes to query $\keyOracle^*$, $t_+$ is the time it takes to sum two arbitrary group elements, and $t_{\texttt{base}}$ is the time it takes to simulate a query $H_{\texttt{base}}$. This query succeeds with certainty.

\item When $\mathcal{A}_1$ queries $\corruptionOracle$ with some $(i, (\tvk, \VK))$, $\mathcal{A}_2$ parses $(Y_i, Z_1, \ldots, Z_{d-1}) := \vk_i$. If this is not possible, then $\corruptionOracle$ responds with a distinct failure symbol. 
Otherwise, $\mathcal{A}_2$ looks up $z_k \leftarrow T_{\texttt{DL}}[Z_k]$ for each $k$. If this is not possible, then $\corruptionOracle$ responds with a distinct failure symbol. Otherwise, $\mathcal{A}_2$ queries $y_i \leftarrow \corruptionOracle^*(Y_i)$, sets $T_{\texttt{corrupt}}[Y_i] = y_i$, and responds with $(y_i, z_1, \ldots, z_{d-1})$.

This query takes one query to $\corruptionOracle^*$ and $d-1$ retrievals from $T_{\texttt{DL}}$. As this is a hash table, lookups are constant-time, so this query takes time at most $t_{\texttt{corrupt}} = t_{\texttt{corrupt}}^* + (d-1)O(1)$.  Moreover, this query fails if and only if $\mathcal{A}_1$ makes a query that is not a challenge key. By assumption, $\mathcal{A}_1$ prefers to fail than to make a failed corruption oracle query, so without loss of generality, this corruption oracle certainly succeeds.

This is the only oracle which may fail if queried incorrectly, say with non-challenge data.

\item When $\mathcal{A}_1$ queries $\signingOracle$ with some $(\msg, \ring, \tvk, \VK, \vk)$, $\mathcal{A}_2$ does the following to back-patch an ostensibly valid signature.
\begin{enumerate}
\item If $(\tvk, \VK^\prime)$ does not appear as a $\keyOracle$ response to $\mathcal{A}_1$ for any $\VK \subseteq \VK^\prime$, or $\tvk \notin \ring$, output a distinct failure symbol and terminate.
\item Otherwise, there is some query made by $\mathcal{A}_1$ to $\keyOracle$ with keys matching this $\signingOracle$ query, say $(\tvk, \VK^\prime) \leftarrow \keyOracle(n,r)$ occurred for some $\VK \subseteq \VK^\prime$. If $\left|\VK\right| < r$, or $\left|\VK^\prime\right| \neq n$, output a distinct failure symbol and terminate.  
\item Otherwise, there is a superthreshold number of signers in the coalition and the correct total number of keyholders. Parse $(Y, Z_1, \ldots, Z_{d-1}) := \tvk$.
\item Retrieve $\alpha = T_{\texttt{base}}[Y]$, then compute $\mathfrak{T} = \alpha Y$ and each $\mathfrak{D}_k = \alpha Z_k$. Set $\tlt = (\mathfrak{T}, \mathfrak{D}_1, \ldots, \mathfrak{D}_{d-1})$.

\item Simulate a query made to $H_{\texttt{base}}$ by $\mathcal{A}_1$, say $\widehat{Y}_j = H_{\texttt{base}}(Y_j)$, for each ring members' linking keys $Y_j$ (i.e.\ for each $j \in [m]$).
\item Simulate a query made to $H_{\lt}^*$ and $H_{\lt, k}$ from $\mathcal{A}_1$ for each $k \in [d-1]$ to obtain $\mu_Y = H_{\lt}^*(\ring \mid \mid \tlt \mid \mid \underline{\widehat{Y}})$ and $\mu_k = H_{\lt, k}(\ring \mid \mid \tlt \mid \mid \underline{\widehat{Y}})$ for each $k \in [d-1]$.
\item Compute $W_j = \mu_Y Y_j + \sum_k \mu_k Z_{j,k}$ for each ring member $\tvk_j = (Y_j, Z_{j,1}, \ldots, Z_{j,d-1})$.
\item Compute $\mathfrak{W} = \mu_Y \mathfrak{T} + \sum_k \mu_k \mathfrak{D}_k$.
\item Sample $s_1, \ldots, s_m \leftarrow \Zq$.
\item Retrieve $i^* = \left|T_{\texttt{ch}}\right| + 1$ and the challenges $h_{i^*}, h_{i^*+1}, \ldots, h_{i^*+m-1} \leftarrow \underline{h}$.
\item Find $j^* \in [m]$ such that $\tvk_{j^*} = \tvk$.
\item Set the following:

\vspace{-1em}

\begin{align*}
c_{j^*+1} &= h_{i^*} & c_m &= h_{i^* + (m-j^* - 1)} \\
c_{j^*+2} &= h_{i^*+1} & c_1 &= h_{i^* + (m-j^*)} \\
% c_{j^*+3} &= h_{i^*+2} & c_2 &= h_{i^* + (m-j^*) + 1} \\
\vdots & & \vdots & \\
% c_{m-2} &= h_{i^* + (m-j^*-3)} & c_{j^* - 1} &= h_{i^* + (m-2)} \\
c_{m-1} &= h_{i^* + (m-j^*-2)} & c_{j^*} &= h_{i^* + (m-1)}
\end{align*}

\vspace{-1em}

% \begin{align*}
% c_{j^*+1} &= h_{i^*}, c_{j^*+2} = h_{i^*+1}, \dots c_{m-2} = h_{i^* + (m-j^*-3)}, c_{m-1} = h_{i^* + (m-j^*-2)}  \\
% c_m &= h_{i^* + (m-j^* - 1)}, \ c_1 = h_{i^* + (m-j^*)}, \ \dots \ c_{j^* - 1} = h_{i^* + (m-2)}, \ c_{j^*} = h_{i^* + (m-1)}
% \end{align*}




\item If any
$\texttt{query} = \signaturequery \in T_{\texttt{ch}}$, then output a distinct failure symbol and terminate. 

\item For $j \in [m]$, $T_{\texttt{ch}}\signaturequery := c_{j+1}$.
\item Set $\sig = (c_1, s_1, \ldots, s_m, \mathfrak{T}, \mathfrak{D}_1, \ldots, \mathfrak{D}_{d-1})$.
\item Respond with $\sig$.
\end{enumerate}
This query requires one simulated query to $H_{\lt}^*$, one query to $H_{\lt, k}$ for each $k \in [d-1]$, and one query to $H_{\texttt{base}}$ for each ring member. This query requires a lookup in $T_{\texttt{key}}$, a lookup in $T_{\texttt{key}}$, a lookup in $T_{\texttt{base}}$, and $m$ lookups in $\underline{h}$. This query takes time $t_{\texttt{\sign}} \approx t_{\lt, y} + (d-1)t_{\lt,k} + t_{\texttt{base}} + (2+m)O(1)$. The only way this algorithm fails is if $\mathcal{A}_1$ makes a poorly-formed query. By assumption, $\mathcal{A}_1$ prefers to output a distinct failure symbol than do so. That is, this simulation of $\signingOracle$ succeeds with certainty. 
\end{enumerate}


\item If $\mathcal{A}_1$ outputs a distinct failure symbol and terminates, then $\mathcal{A}_2$ does also.
\item Otherwise, $\texttt{out}_{1} \leftarrow \mathcal{A}_1$. In this event, $\mathcal{A}_2$ parses $(\msg, \ring, \sig) \leftarrow \texttt{out}_1$, sets $m = \left|\ring\right|$, and then does the following.
\begin{enumerate}
\item Find all queries $\texttt{query} \in T_{\texttt{ch}}$, $\ell \in [\kappa_{\texttt{ch}}]$, $j \in [m]$, $c\in\Zq$ such that $T_{\texttt{ch}}[\texttt{query}]=(\ell, c)$, $\tvk_j \in \ring$, and $c=c_{j+1}$ is used to verify $\sig$; call this set of queries $S$.
\item \label{step:whereA2fails} If $S = \emptyset$, output a distinct failure symbol and terminate.
\item Otherwise, find the argument $\texttt{query} \in S$ which minimizes $\ell \in T_{\texttt{ch}}[\texttt{query}]$; i.e.\ the index of the first $H_{\texttt{ch}}$ query used during verification.
\item Set $\texttt{tables}$ to consist of all the tables $\left\{T_{\texttt{label}}\right\}$.
\item Set $\texttt{out}_2 = (\ell, \texttt{out}_1, \texttt{tables})$ for this minimal $\ell$.
\end{enumerate}
\item Output $\texttt{out}_2$.
\end{enumerate}

\vspace{-1em}

The random oracles $H_{\texttt{seed}}$, $H_{\texttt{FROST}, i}$, $H_{\lt, k}$, and $H_{\texttt{base}}$ are all clearly simulated correctly, in the standard way which is indistinguishable from random oracles.  Moreover, $H_{\texttt{ch}}$ is also simulated correctly, up to the quality of the randomness used for the input $\underline{h}$. $\corruptionOracle$ is also correct, as the simulator knows the table $T_{\texttt{DL}}$ and has access to $\corruptionOracle^*$. 
Certainly $\keyOracle$ is simulated correctly, as the computation of the $Y_i$ and $Y$ points correctly simulates FROST key generation, and the remainder of the response is computed honestly.
Now, consider $\signingOracle$. By construction, the output of $\signingOracle$ is a ring signature which passes verification. Moreover, since $H_{\lt,k}$ and $H_{\texttt{base}}$ are simulated correctly, this simulation of $\signingOracle$ is correct, also, at least up to randomness used to sample $\underline{h}$.
Thus, $\mathcal{A}_2$ is a correct simulation of the unforgeability challenger for $\mathcal{A}_1$.

Now, consider the runtime of $\mathcal{A}_2$. If $t_{\texttt{label}}$ denotes the time it takes to simulate each query made to $H_{\texttt{label}}$ or $\mathcal{O}_{\texttt{label}}$, and $\kappa_{\texttt{label}}$ is the number of such queries, then $\mathcal{A}_2$ takes up to $\kappa_{\texttt{label}}t_{\texttt{label}}$ time for all these queries to $H_{\texttt{label}}$. So, $\mathcal{A}_2$ takes time

\vspace{-1.5em}

\begin{align*}
t_2 &\approx  t_1 + n_{\texttt{key}}\kappa_{\texttt{key}}t_{\texttt{key}} + \kappa_{\sign}t_{\sign} +  \kappa_{\texttt{base}}t_{\texttt{base}} + \sum_{\texttt{label} \notin \left\{\texttt{key}, \sign, \texttt{base}\right\} }\kappa_{\texttt{label}} t_{\texttt{label}} 
% &\approx  t_1 + n_{\texttt{key}}\kappa_{\texttt{key}}t_{\texttt{key}} + \kappa_{\sign}t_{\sign} +  \kappa_{\texttt{base}}t_{\texttt{base}}
\end{align*}

\vspace{-1em}

where the times $t_{\texttt{label}}$ in the sum are assumed to be negligible, hence vanish, and where $\mathcal{A}_1$ makes some $\kappa_{\texttt{key}}$ queries to $\keyOracle$, and each of these is handled with up to $n_{\texttt{key}}$ queries to $\keyOracle^*$. Although we assume querying $\keyOracle^*$ takes negligible time, the wrapper used to simulate responses from $\keyOracle$ requires sampling randomness and assembling the response. 

Now consider the success probability. Certainly $\mathcal{A}_2$ succeeds at simulating all oracle queries, so $\mathcal{A}_2$ can only terminate with a distinct failure symbol if $\mathcal{A}_1$ fails, or if no index $\ell$ exists as described above.
However, we claim that if $\mathcal{A}_1$ succeeds, then $T_{\texttt{ch}}$ contains a suitable pair $(\ell,  c)$ except with negligible probability. Indeed, if $\mathcal{A}_1$ outputs a successful forgery with ring signature $\sig = (c_1, \underline{s}, \tlt)$ which passes verification, then $\mathcal{A}_1$ selected this signature to satisfy the equations.

For this forgery to pass verification, these $c_j$ must be consistent with responses from the random oracle $H_{\texttt{ch}}$ when queried by a verifier. So, $\mathcal{A}_1$ guessed or queried $H_{\texttt{ch}}$ for these $c_j$.
Guessing one $\Zq$ output of $H_{\texttt{ch}}$ successfully from amongst some $\kappa \in \N$ queries succeeds with probability at most $\prod_{i \in [\kappa]} (q-i)^{-1}$, which is negligible in $q$.  Since $q \in \polysecpar$, this probability is negligible in $\secpar$. Thus, the probability that no index $\ell$ can be found is negligible, and $\epsilon_2 \approx \epsilon_1$. 






\textbf{Fork this simulator.} 
Note that $\mathcal{A}_2$ is compatible with \cref{def:general_forking_algorithm}, leading to the forking algorithm.
Define $\mathcal{A}_3$ to be similar to $\texttt{Fork}_{\mathcal{A}_2}$ as in 
\cref{def:general_forking_algorithm}, except with oracle access to $\keyOracle^*$ and $\corruptionOracle^*$ from \cref{def:omdl}. Then \cref{lem:general_forking_lemma} implies $\mathcal{A}_3$ is a PPT $(t_3, \epsilon_3)$-algorithm where

\vspace{-1em}

$$t_3 = 2t_2+t_2^\prime \approx 2t_2 \in \negl, \quad \text{ and } \quad \epsilon_3 = \epsilon_2\left(\frac{\epsilon_2}{\kappa_{\texttt{ch}}} - \frac{1}{q-1}\right) \in O\left(\frac{\epsilon_2^2}{\kappa_{\texttt{ch}}}\right)$$

% \begin{align*}
% t_3  &= 2t_2+t_2^\prime \approx 2t_2 \in \negl \\
%  \epsilon_3 &= \epsilon_2\left(\frac{\epsilon_2}{\kappa_{\texttt{ch}}} - \frac{1}{q-1}\right) \in O\left(\frac{\epsilon_2^2}{\kappa_{\texttt{ch}}}\right)
% \end{align*} 
where $t_2^\prime \in \negl$ is the additional time it takes to sample randomness in \cref{def:general_forking_algorithm}. 

\textbf{Solve OMDL.} Lastly, we build an algorithm $\mathcal{A}_4$ which has access to $\keyOracle^*$ and $\corruptionOracle^*$ as defined in \cref{def:omdl} (and which we assume take negligible time to invoke), runs $\mathcal{A}_3$ as a subroutine, and plays the $\kappa$-OMDL game in time at most $t_4$ and succeeds with probability at least $\epsilon_4$ as follows, where $\kappa =n_{\texttt{key}}\kappa_{\texttt{key}} - 1$.

Observe that $\mathcal{A}_2$ makes some $\texttt{query}$ at the fork point. Moreover, this fork point is selected so that the response appears in verification. Thus, $\texttt{query} = \signaturequery$ for some $j \in [m]$ and for some points $L_j, R_j \in \G$, and $T_{\texttt{ch}}[\texttt{query}] = c_{j+1}$. All data available to $\mathcal{A}_2$, as well as its random tape, are identical until the fork point. Thus, the queries are identical on both sides of the fork with certainty, but by the definition of \cref{def:general_forking_algorithm}, the responses vary in both transcripts except with negligible probability. In particular, the points $L_j$ and $R_j$ are common to both transcripts with certainty.  That is to say, we see the same query with two distinct responses $c_{j+1} \neq c^\prime_{j+1}$.
% \[
% \begin{tikzcd}[row sep=large, column sep=0pt] 
%     H_{\texttt{ch}}\signaturequery \arrow[d, shift left, shift left, shift left] \arrow[d, shift right, shift right, shift right] \\
%     c_{j+1} \neq c^\prime_{j+1}
% \end{tikzcd}
% \]
That is to say, on one side of the fork, the same query yields the response $c_{j+1}$, and on the other side of the fork, the different response $c_{j+1}\neq c_{j+1}^\prime$.
Since $\lt = (\mathfrak{T}, \mathfrak{D}_1, \ldots, \mathfrak{D}_{d-1})$ appears in this query, these points are certainly identical on both sides of the fork. 

\vspace{-1em}

\begin{enumerate}
\item Run $\mathcal{A}_3$ as a subroutine, responding to $\keyOracle^*$ and $\corruptionOracle^*$ queries by consulting these oracles and responding faithfully.  If $\mathcal{A}_3$ fails, then $\mathcal{A}_4$ outputs a distinct failure symbol and terminates. This step takes time $t_3$ and succeeds with probability $\epsilon_3$.

\item Otherwise, $\texttt{out}_{\mathcal{A}_3} \leftarrow \mathcal{A}_3$. If $\mathcal{A}_4$ cannot parse $(\ell, (\texttt{out}_{\mathcal{A}_1}, \texttt{tables}), (\texttt{out}_{\mathcal{A}_1}^\prime, \texttt{tables}^\prime)) := \texttt{out}_{\mathcal{A}_3}$, then $\mathcal{A}_4$ outputs a distinct failure symbol and terminates. This takes negligible time. By construction of $\mathcal{A}_4$, this step, conditioned on the success of the previous step, certainly succeeds.

\item Otherwise, $\mathcal{A}_4$ attempts to parse the following.

\vspace{-2em}

\begin{align*}
(\msg, \ring, \sig) &:= \texttt{out}_{\mathcal{A}_1} & (\msg^\prime, \ring^\prime, \sig^\prime) &:= \texttt{out}_{\mathcal{A}_1}^\prime \\
(\tvk_1, \ldots, \tvk_m) &:= \ring, &
(\tvk_1^\prime, \ldots, \tvk_{m^\prime}^\prime) &:= \ring^\prime, \\
(c_1, \underline{s}, \tlt) &:= \sig &
(c_1^\prime, \underline{s}^\prime, \tlt^\prime) &:= \sig^\prime \\
(\mathfrak{T}, \underline{\mathfrak{D}}) &:= \tlt & (\mathfrak{T}^\prime, \underline{\mathfrak{D}}^\prime) &:= \tlt 
\end{align*}

\vspace{-1em}

If $\mathcal{A}_4$ cannot parse this, then $\mathcal{A}_4$ outputs a distinct failure symbol and terminates. By construction of $\mathcal{A}_3$, this step, conditioned on the success of the previous step, certainly succeeds.

\item For each $j \in [m]$, $\mathcal{A}_4$ searches for each $\texttt{query}_j$ such that $T_{\texttt{ch}}[\texttt{query}_j]=(\ell_j, c_{j+1})$. This $\ell_j$ is the $H_{\texttt{ch}}$ query index whose response is $c_{j+1}$ used during verification. For the signature challenge $c_{j+1}$ used in verification, call this set $S_1$. Recalling that the forger makes all these queries to $H_{\texttt{ch}}$ in every successful transcript except with negligible probability, then conditioned on the success of the previous steps, this step succeeds except with negligible probability. Moreover, this step takes time at most $O(\kappa_{\texttt{ch}})$ in case we must touch every entry in $T_{\texttt{ch}}$.

\item Find the $j^* \in [m]$ such that $\texttt{query}_{j^*} \in S$ minimizes $\ell_{j^*} \in T_{\texttt{ch}}[\texttt{query}_{j^*}]$. This way, $c_{j^*}$ is the first oracle response used during verification.

\item $\mathcal{A}_4$ parses $\signaturequerystar:= \texttt{query}_{j^*}$ for some points $L_{j^*}, R_{j^*} \in \G$. If $\mathcal{A}_4$ cannot do this, then $\mathcal{A}_4$ outputs a distinct failure symbol and terminates. This takes negligible time. Say this step succeeds with probability $\epsilon^\prime$, and see below.

\item For this $j^*$, parse $(Y_{j^*}, Z_{j^*, 1}, \ldots, Z_{j^*, d-1}) := \tvk_{j^*}$ (where $\tvk_{j^*} \in \ring$). Retrieve $\mu_y \leftarrow T_{\lt}^*[\ring \mid \mid \tlt]$ and, for each $k \in [d-1]$, $\mu_k \leftarrow T_{\lt, k}[\ring \mid \mid \tlt]$.

\item $\mathcal{A}_4$ computes $\widetilde{w}_{j^*} = \frac{s_{j^*} - s_{j^*}^\prime}{c_{j^*}^\prime - c_{j^*}}$. This takes the time of two negations, two additions, an inversion, and a multiplication in $\Zq$, say $2t_{\texttt{neg}} + 2t_{+} + t_{\texttt{inv}} + t_{\texttt{mul}}$. By the construction of $\mathcal{A}_3$, and conditioned on the previous step's success, $c_{j^*}^\prime \neq c_{j^*}$ with certainty, so this step succeeds with certainty.

\item $\mathcal{A}_4$ finds a response $(\tvk, \VK) \leftarrow \keyOracle(n,r)$ to a query made by $\mathcal{A}_1$ such that $\tvk = \tvk_{j^*}$, and parses $(\vk_1, \ldots, \vk_n) := \VK$. This takes negligible time, and, conditioned on the success of the previous step, this step certainly succeeds.


\item If $\tvk_{j^*} \in \mathcal{L}^{\texttt{tot}}_{\texttt{corrupt}}$, output a distinct failure symbol and terminate. Otherwise, for this $\VK$, let $C = \VK \cap \mathcal{L}_{\texttt{corrupt}}$ be the set of corrupted public verification key shares corresponding to the total verification key ring member $\tvk_j$. This step takes negligible time. Moreover, conditioned on the success of the previous step, this step succeeds with certainty. Indeed, $\mathcal{A}_1$ would have failed (causing a cascade of failures) if too many key shares had been corrupted.


\item Otherwise, $\left|C\right| < r-1$. In this event, $\mathcal{A}_4$ selects $r-1-\left|C\right|$ uncorrupted keys associated with $\tvk_{j^*}$ to parse, say $(Y_i, Z_1, \ldots, Z_{d-1}) := \vk_i$, and corrupts them by querying $y_i \leftarrow \corruptionOracle^*(Y_i)$, until $\left|C\right| = r-1$ exactly. This step takes negligible time and certainly succeeds. 

\item Compute the indices $I \subseteq [n]$ of keys in $\VK$ corresponding to the elements in $C$, and compute the Lagrange interpolation coefficients $\lambda_i$ for $I \in [n]$.

\item $\mathcal{A}_4$ picks an uncorrupted challenge key of $\VK$, say $\vk_{i^*}$, and parses $(y_{i^*}, z_1, \ldots, z_{d-1}) :=  \vk_{i^*}$. This is the target challenge key. This step takes negligible time and succeeds with certainty.

\item $\mathcal{A}_4$ computes the Lagrange interpolation coefficients corresponding to the target challenge key $\vk_{i^*}$ and the corrupted keys $(Y_i, Z_1, \ldots, Z_{d-1})$ for each $i \in I$. Call these $\lambda_{i^*}$ for $\vk_{i^*}$, and $\lambda_i$ for each $\vk_i$ with $i \in I$. This takes $r(r-1)$ multiplications and certainly succeeds. Moreover, the Lagrange interpolation coefficients are all nonzero with certainty.


\item $\mathcal{A}_4$ computes the following.

\vspace{-1em}

$$z^* = \sum_{k \in [d-1]} \mu_k z_k, \quad
\overline{y} = \sum_{i \in I, i \neq i^*} \lambda_i y_i, \quad \text{and} \quad
y_{j^*,i^*} = \lambda_{i^*}^{-1}\left(\mu_y^{-1}\left(\widetilde{w}_{j^*} - z^*\right) - \overline{y}\right)$$


% \begin{align*}
% z^* &= \sum_{k \in [d-1]} \mu_k z_k \\
% \overline{y} &= \sum_{i \in I, i \neq i^*} \lambda_i y_i \\
% y_{j^*,i^*} &= \lambda_{i^*}^{-1}\left(\mu_y^{-1}\left(\widetilde{w}_{j^*} - z^*\right) - \overline{y}\right)
% \end{align*} 
Then $\mathcal{A}_4$ sets $\texttt{out}_4 = \mathcal{L}_{\texttt{corrupt}} \cup \left\{y_{j^*, i^*}\right\}$.
Computing $z^*$ takes time $(d-1)t_{\texttt{mul}} + (d-1)t_{+}$, computing $\overline{y}$ takes time $(r-1)t_{\texttt{mul}} + (r-1)t_{+}$, and computing $y_{j^*,i^*}$ from these takes time $2t_{\texttt{mul}} + 2t_{+}$. These all certainly succeed. Thus, this step takes $(r+d)(t_{\texttt{mul}} + t_+)$ time.
\end{enumerate}

Consider the correctness of the composition of all these algorithms $\mathcal{A}_4$ through $\mathcal{A}_1$ as a $\kappa$-OMDL player. Given the auxiliary keys $z_1, \ldots, z_{d-1}$ and the aggregation coefficients, the aggregated key $w$ yields the linking key $y=\mu_Y^{-1}(w-\sum_k \mu_k z_k)$, and given the $r-1$ corrupted secret signing key shares $y_i$ and the value $y$, Lagrange interpolation implies $y = \lambda_{i^*} y_{j^*,i^*} + \sum_{i \in I, i \neq i^*} \lambda_i y_{i}$. Since this is a successful forgery, all ring members are challenge keys. Solving these for $y_{j^*,i^*}$ provides correctness.

$\mathcal{A}_4$ takes time $t_4 \approx t_3 + (r+2)t_{+} + 3t_{\texttt{inv}} + 2t_{\texttt{scmul}} + O(\kappa_{\texttt{ch}}) + 2t_{\texttt{neg}} + r^2t_{\texttt{mul}} + (r-1-\left|C\right|)t_{\texttt{corrupt}}$,
obtained by summing the times of each step above. However, $r$ is selected by $\mathcal{A}_4$ in the course of executing $\mathcal{A}_1$. Moreover, the strongest adversary corrupts no keys at all. So, we use $r \leq n \leq n_{\texttt{ch}}$ and $r-1-\left|C\right| \leq n_{\texttt{ch}}-1$ to obtain 

\vspace{-1.5em}

\[t_4 \approx t_3 + (n_{\texttt{ch}}+2)t_{+} + 3t_{\texttt{inv}} + 2t_{\texttt{scmul}} + O(\kappa_{\texttt{ch}}) + 2t_{\texttt{neg}} + n_{\texttt{ch}}^2t_{\texttt{mul}} + (n_{\texttt{ch}}-1)t_{\texttt{corrupt}}.\] 

\vspace{-1em}

% Now consider the runtime. 
% $\mathcal{A}_4$ takes time \[t_4 \approx t_3 + (r+2)t_{+} + 3t_{\texttt{inv}} + 2t_{\texttt{scmul}} + O(\kappa_{\texttt{ch}}) + 2t_{\texttt{neg}} + r^2t_{\texttt{mul}} + (r-1-\left|C\right|)t_{\texttt{corrupt}}\] 



However, $t_3 \approx 2t_2 \approx 2(t_1 + n_{\texttt{key}}\kappa_{\texttt{key}}t_{\texttt{key}} + \kappa_{\sign}t_{\sign} + \kappa_{\texttt{corrupt}}t_{\texttt{corrupt}} + \kappa_{\texttt{base}} t_{\texttt{base}})$, 
so 
% $t_4 \approx 2t_1 + \widetilde{t}$ where
\begin{align*}
t_4 &\approx 2t_2 + 2n_{\texttt{key}}\kappa_{\texttt{key}}t_{\texttt{key}} + 2\kappa_\sign t_\sign + 2\kappa_{\texttt{corrupt}}t_{\texttt{corrupt}} + 2\kappa_{\texttt{base}}t_{\texttt{base}} + \\
& (n_{\texttt{ch}}+2)t_{+} + 3t_{\texttt{inv}} + 2t_{\texttt{scmul}} + O(\kappa_{\texttt{ch}}) + 2t_{\texttt{neg}} + n_{\texttt{ch}}^2t_{\texttt{mul}} + (n_{\texttt{ch}}-1)t_{\texttt{corrupt}}
\end{align*}

Now consider success probability. If $\mathcal{A}_3$ succeeds, $\mathcal{A}_4$ can fail if the $\texttt{query}$ made to $H_{\texttt{ch}}$ such that $T_{\texttt{ch}}[\texttt{query}]=(\ell, c)$ cannot be parsed as $\signaturequery$. We denoted above the probability that $\texttt{query}$ cannot be parsed appropriately with $\epsilon^\prime$.

All that remains is to show $\epsilon^\prime$ is negligible. Indeed, the $\texttt{query}$ satisfies $T_{\texttt{ch}}[\texttt{query}]=(\ell, c)$ where $c=c_{j+1}$ is used in verification.  If $\texttt{query}$ cannot be parsed as $\signaturequery$, but $c_{j+1}$ is used in verification, then there is some other $\texttt{query}^\prime \in T_{\texttt{ch}}$ with this $c$. This is a second pre-image for $\texttt{query}$ for the random oracle $H_{\texttt{ch}}$, so this $\epsilon^\prime \in \negl$.

\end{proof}

\vspace{-2em}

\subsection{Linkability}

\vspace{-0.5em}


\begin{theorem}
FROSTLASS is linkable under \cref{def:linkable}. 
\end{theorem}

\vspace{-1em}

\begin{proof}
Let $\kappa \in \mathbb{N}$ and let $\mathcal{A}$ be a $\kappa$-linkability breaker. 
We build a tower of algorithms, $\mathcal{A}_3 \to \mathcal{A}_2 \to \mathcal{A}_1$, where $\mathcal{A}_1 = \mathcal{A}$, similar to those in \cref{thm:suf}, to extract the discrete logarithm of an aggregated ring member which is under adversarial control. We use this discrete logarithm to show the linkability tag is, except with negligible probability, the image of the linking key under a collision-resistant function.

First, recall $\mathcal{A}_2$ in \cref{thm:suf} was a five-step algorithm. We let $\mathcal{A}_2$ operate similarly to $\mathcal{A}_2$ from \cref{thm:suf}, modifying the following steps:

\vspace{-1em}

\begin{enumerate}
\setcounter{enumi}{3}
\item Otherwise, $\texttt{out}_1 \leftarrow \mathcal{A}_1$. In this event, $\mathcal{A}_2$ parses the first message-ring-signature triple present, $(\msg, \ring, \sig) \leftarrow \texttt{out}_1$, sets $m = \left|\ring\right|$, and does the following.
\begin{enumerate}
\item Find all queries $\texttt{query} \in T_{\texttt{ch}}$, $\ell \in [\kappa_{\texttt{ch}}]$, $j \in [m]$, $c \in \Zq$ such that $T_{\texttt{ch}}[\texttt{query}] = (\ell, c)$, $\tvk_j \in \ring$ is not an uncorrupted challenge key, and $c=c_{j+1}$ is used to verify $\sig$; call this set of queries $S$.
\end{enumerate}
\end{enumerate}

\vspace{-1em}

All other steps are otherwise similar to \cref{thm:suf}. That we fork only on queries related to uncorrupted challenge keys is critically important here, just as forking only on challenge keys was critical in \cref{thm:suf}. As before, $\mathcal{A}_2$ is compatible with the forking algorithm, so let $\mathcal{A}_3 = \texttt{Fork}_{\mathcal{A}_2}$ as in \cref{thm:suf}. Now consider a successful output of $\mathcal{A}_3$. 

The forking query  $\signaturequerystar$ is the same on both sides of the fork. Moreover, in one transcript we obtain $L_{j^*} = s_{j^*} G + c_{j^*} W_{j^*}$ where $W_{j^*}$ is the aggregation of the ring member with index $j^*$, and in the other transcript the same $L_{j^*}$ satisfies $L_{j^*} = s_{j^*}^\prime G + c_{j^*}^\prime W_{j^*}$. Thus, just as before, we obtain the discrete logarithm $W_{j^*} = \frac{s_{j^*} - s_{j^*}^\prime}{c_{j^*}^\prime - c_{j^*}}G$. However, this $W_{j^*} = \mu_Y Y_{j^*} + \sum_k \mu_k Z_{j^*,k}$. Thus, if $y_{j^*}$ is the discrete logarithm of $Y_{j^*}$ with respect to $G$ and each $z_{j^*,k}$ is the discrete logarithm of $Z_{j^*,k}$ with respect to $G$, then $\frac{s_{j^*} - s_{j^*}^\prime}{c_{j^*}^\prime - c_{j^*}} = \mu_Y y_{j^*} + \sum_k \mu_k z_{j^*,k}$. Note this equation holds for these scalars, even though we do not (and perhaps even $\mathcal{A}$ may not) know them.

Also, we obtain in one transcript $R_{j^*} = s_{j^*} \widehat{Y}_{j^*} + c_{j^*} \mathfrak{W}$ where $\mathfrak{W}$ is the aggregation of the linking tag base points $\mathfrak{T}$ and $\mathfrak{D}_k$. In the other transcript, the same $R_{j^*}$ satisfies $R_{j^*} = s_{j^*}^\prime \widehat{Y}_{j^*} + c_{j^*}^\prime \mathfrak{W}$. Thus, just as before, we obtain the discrete logarithm $\mathfrak{W} = \frac{s_{j^*} - s_{j^*}^\prime}{c_{j^*}^\prime - c_{j^*}}\widehat{Y}_{j^*}$. However, $\mathfrak{W} = \mu_Y \mathfrak{T} + \sum_k \mu_k \mathfrak{D}_k$, so $\frac{s_{j^*} - s_{j^*}^\prime}{c_{j^*}^\prime - c_{j^*}}\widehat{Y}_{j^*} = \mu_Y \mathfrak{T} + \sum_k \mu_k \mathfrak{D}_k$.
Re-arranging, we have $\mu_Y\left(y_{j^*} \widehat{Y}_{j^*} - \mathfrak{T}\right) + \sum_k \mu_k\left(z_{j^*,k} \widehat{Y}_{j^*} - \mathfrak{D}_k\right) = 0$, which can only be satisfied if $\mathfrak{T} = \widehat{Y}_{j^*}$, except with negligible probability. 
Since $\mathfrak{T}$ is a collision-resistant function of $y_{j^*}$, we conclude that valid signatures, except with negligible probability, have linking tags which are collision-resistant functions of some ring member which is not an uncorrupted challenge key. This prevents more linking tags than linking keys.
\end{proof}











% % \newpage
% % \begin{appendices}% \addcontentsline{toc}{section}{Appendix} % Add the appendix text to the document TOC
% % \part{Appendix} % Start the appendix part
% % \parttoc % Insert the appendix TOC


% \startcontents[sections]
% \printcontents[sections]{l}{1}{\setcounter{tocdepth}{2}}
\appendix
% \appendixpage
% % \addcontentsline{toc}{chapter}{Appendix}

% \section{Introduction}

% We review the Rust implementation of FROSTLASS, the \path{/serai-dex/serai/networks/monero/} directory in commit \texttt{48db06f} by \texttt{KayabaNerve} of the GitHub repository at \url{github.com/serai-dex/serai}. This directory contains a Rust implementation of Monero wallet functionality, together with a new approach to using FROST for threshold signing. All files, folders, and subfolders of \path{/serai-dex/serai/networks/monero/} are in scope for the audit, except not the subfolder \path{/serai-dex/serai/networks/monero/verify-chain/}.


























% % A bunch of glossary entries
%     \newglossaryentry{monero-wallet (v0.1.0)}{
%         name={\protect\texttt{monero-wallet (v0.1.0)}},
%         description={A standard library crate, with the corresponding entry point at  \path{/wallet/src/lib.rs}. Handles all wallet functionality}
%     }

%     \newglossaryentry{monero-simple-request-rpc (v0.1.0)}{
%         name={\protect\texttt{monero-simple-request-rpc (v0.1.0)}},
%         description={A standard library crate, with the corresponding entry point at  \path{/rpc/simple-request/src/lib.rs}. Default RPC to avoid external dependences, e.g. reqwest}
%     }

%     \newglossaryentry{monero-rpc (v0.1.0)}{
%         name={\protect\texttt{monero-rpc (v0.1.0)}},
%         description={A standard library crate, with the corresponding entry point at \path{/rpc/src/lib.rs}. It defines traits and types for retrieving blockchain data, managing transactions, and selecting decoy outputs for ring signatures. The crate implements both standard JSON-RPC and Monero-specific binary protocols, with a focus on security when dealing with potentially untrusted nodes.}
%     }

%     \newglossaryentry{monero-serai (v0.1.4-alpha)}{
%         name={\protect\texttt{monero-serai (v0.1.4-alpha)}},
%         description={A standard library crate, with the corresponding entry point at \path{/src/lib.rs}. This is the overall transaction library}
%     }

%     \newglossaryentry{monero-address (v0.1.0)}{
%         name={\protect\texttt{monero-address (v0.1.0)}},
%         description={A standard library crate, with the corresponding entry point at \path{/wallet/address/src/lib.rs}. Handles Monero addresses}
%     }

%     \newglossaryentry{monero-borromean (v0.1.0)}{
%         name={\protect\texttt{monero-borromean (v0.1.0)}},
%         description={A standard library crate, with the corresponding entry point at \path{/ringct/borromean/src/lib.rs}. Employs no modules, and untested. Handles Borromean signatures and Borromean range proofs}
%     }


%     \newglossaryentry{monero-bulletproofs (v0.1.0)}{
%         name={\protect\texttt{monero-bulletproofs (v0.1.0)}},
%         description={A standard library crate, with the corresponding entry point at \path{/ringct/bulletproofs/src/lib.rs}. Handles original bulletproofs and bulletproofs plus}
%     }

%     \newglossaryentry{monero-clsag (v0.1.0)}{
%         name={\protect\texttt{monero-clsag (v0.1.0)}},
%         description={A standard library crate, with the corresponding entry point at \path{/ringct/clsag/src/lib.rs}. Handles CLSAG ring signatures and a FROST-like thresholdization.}
%     }

%     \newglossaryentry{monero-mlsag (v0.1.0)}{%
%       name={\protect\texttt{monero-mlsag (v0.1.0)}},
%       description={A Rust crate located at \path{/networks/monero/ringct/mlsag/src/lib.rs} providing
%       Multilayered Linkable Spontaneous Anonymous Group (MLSAG) ring signatures for the Monero protocol.
%       Maintains core MLSAG structures (\texttt{RingMatrix} and \texttt{Mlsag}) and an aggregate
%       matrix builder. Implements zeroization, but needs expanded testing and finer-grained error handling.}
%     }

%     \newglossaryentry{monero-primitives (v0.1.0)}{
%         name={\protect\texttt{monero-primitives (v0.1.0)}},
%         description={A standard library crate, with the corresponding entry point at \path{/primitives/src/lib.rs}.}
%     }

%     \newglossaryentry{monero-generators (v0.4.0)}{
%         name={\protect\texttt{monero-generators (v0.4.0)}},
%         description={A standard library crate, with the corresponding entry point at \path{/generators/src/lib.rs}. Handles hashing to elliptic curve group elements and computing fixed generators for use in the Monero protocol}
%     }

%     \newglossaryentry{monero-io (v0.1.0)}{
%         name={\protect\texttt{monero-io (v0.1.0)}},
%         description={A standard library crate with entry point at \path{/io/src/lib.rs}. Employs no modules, and untested.  Handles reading and writing various data structures used in Monero protocol computations (e.g.\ bytes, scalars, group elements, lists whose entries are the same type)}
%     }
    
%     \newglossaryentry{decoys-module}{
%         name={\protect\path{/wallet/src/decoys.rs}},
%         description={The module handling decoys.}
%     }

%     \newglossaryentry{extra-module}{
%         name={\protect\path{/wallet/src/extra.rs}},
%         description={The module handling the extra field of transactions.}
%     }

%     \newglossaryentry{output-module}{
%         name={\protect\path{/wallet/src/output.rs}},
%         description={The module handling transaction outputs.}
%     }

%     \newglossaryentry{scan-module}{
%         name={\protect\path{/wallet/src/scan.rs}},
%         description={The module handling scanning.}
%     }

%     \newglossaryentry{view-pair-module}{
%         name={\protect\path{/wallet/src/view_pair.rs}},
%         description={The module handling the (public-spend, private-view) keys.}
%     }

%     \newglossaryentry{send-module}{
%         name={\protect\path{/wallet/src/send/mod.rs}},
%         description={The module handling the sending transactions.}
%     }

%     \newglossaryentry{block-module}{
%         name={\protect\texttt{block}},
%         description={A module in \texttt{monero-serai} handling Monero block structures and related functionality}
%     }

%     \newglossaryentry{merkle-module}{
%         name={\protect\path{/src/merkle.rs}},
%         description={Module for handling Merkle trees}
%     }

%     \newglossaryentry{ring-signatures-module}{
%         name={\protect\texttt{ring\_signatures}},
%         description={A module in \texttt{monero-serai} implementing Monero's ring signature scheme for transaction privacy}
%     }

%     \newglossaryentry{ringct-module}{
%         name={\protect\texttt{ringct}},
%         description={A module in \texttt{monero-serai} implementing RingCT (Ring Confidential Transaction) functionality, including bulletproofs and CLSAG signatures}
%     }

%     \newglossaryentry{transaction-module}{
%         name={\protect\texttt{transaction}},
%         description={A module in \texttt{monero-serai} containing data structures and functionality for Monero transactions, including different transaction versions and serialization/deserialization}
%     }

%     \newglossaryentry{base58-module}{
%         name={\protect\path{/wallet/address/src/base58check.rs}},
%         description={Module for handling base58 enc/dec}
%     }

%     \newglossaryentry{monero-serai-entry-point}{
%         name={\protect\path{/src/lib.rs}},
%         description={Entry point for the monero-serai transaction library}.
%     }
    
%     \newglossaryentry{wallet-tests}{
%         name={\protect\path{/wallet/src/tests/runner/mod.rs}},
%         description={Testing module for \texttt{monero wallet (v0.1.0)}}
%     }

%     \newglossaryentry{wallet-entry-point}{
%         name={\protect\path{/wallet/src/lib.rs}},
%         description={The entry point to the \gls{monero-wallet (v0.1.0)} crate}
%     }

%     \newglossaryentry{monero-simple-request-rpc-entry-point}{
%         name={\protect\path{/rpc/simple-request/src/lib.rs}},
%         description={The entry point to the \gls{monero-simple-request-rpc (v0.1.0)} crate}
%     }
    
%     \newglossaryentry{monero-rpc-entry-point}{
%         name={\protect\path{/rpc/src/lib.rs}},
%         description={Module for handling RPC calls for communicating on the Monero network.}.
%     }


%     \newglossaryentry{monero-serai-tests}{
%         name={\protect\path{/src/tests/mod.rs}},
%         description={Testing module for handling \gls{monero-serai (v0.1.4-alpha)} tests}
%     }

%     \newglossaryentry{address-tests}{
%         name={\protect\path{/wallet/address/src/tests.rs}},
%         description={Testing module for \gls{monero-address (v0.1.0)} tests}
%     }

    
%     \newglossaryentry{borromean-entry-point}{
%         name={\protect\path{/ringct/borromean/src/lib.rs}},
%         description={Entry point to \gls{monero-borromean (v0.1.0)}}
%     }

    
%     \newglossaryentry{bulletproofs-entry-point}{
%         name={\protect\path{/ringct/bulletproofs/src/lib.rs}},
%         description={Entry point to \gls{monero-bulletproofs (v0.1.0)}}
%     }

    
%     \newglossaryentry{bp-batch-verifier-module}{
%         name={\protect\path{/ringct/bulletproofs/src/batch_verifier.rs}},
%         description={Module for handling batch verification of bulletproofs}
%     }

%     \newglossaryentry{bp-core-module}{
%         name={\protect\path{/ringct/bulletproofs/src/core.rs}},
%         description={Module for handling the core folding computation of bulletproofs.}
%     }


%     \newglossaryentry{bp-point-vector-module}{
%         name={\protect\path{/ringct/bulletproofs/src/point_vector.rs}},
%         description={Module for handling the vectors of group elements in bulletproofs.}
%     }


%     \newglossaryentry{bp-scalar-vector-module}{
%         name={\protect\path{/ringct/bulletproofs/src/scalar_vector.rs}},
%         description={Module for handling the vectors of field elements/scalars in bulletproofs.}
%     }


%     \newglossaryentry{bp-original-module}{
%         name={\protect\path{/ringct/bulletproofs/src/original/mod.rs}},
%         description={Module for handling the original bulletproofs}
%     }

%     \newglossaryentry{bp-plus-module}{
%         name={\protect\path{/ringct/bulletproofs/src/plus/mod.rs}},
%         description={Module for handling bulletproofs plus}
%     }

%     \newglossaryentry{bp-test-module}{
%         name={\protect\path{/ringct/bulletproofs/src/plus/mod.rs}},
%         description={Module for handling bulletproofs tests}
%     }

%     \newglossaryentry{monero-clsag-entry-point}{
%         name={\protect\path{/ringct/clsag/src/lib.rs}},
%         description={Entry point for \gls{monero-clsag (v0.1.0)}}
%     }
   
%     \newglossaryentry{clsag-multisig-module}{
%         name={\protect\path{/ringct/clsag/src/multisig.rs}},
%         description={Module for handling CLSAG signatures.}
%     } 

%     \newglossaryentry{clsag-tests}{
%         name={\protect\path{/ringct/clsag/src/tests.rs}},
%         description={Test module for CLSAG signatures.}
%     } 

%     \newglossaryentry{monero-mlsag-entry-point}{
%         name={\protect\path{/ringct/mlsag/src/lib.rs}},
%         description={Entry point for \gls{monero-mlsag (v0.1.0)}}
%     } 

%     \newglossaryentry{monero-primitives-entry-point}{
%         name={\protect\path{/primitives/src/lib.rs}},
%         description={Entry point for \gls{monero-primitives (v0.1.0)}}
%     } 


%     \newglossaryentry{unreduced-scalar-module}{
%         name={\protect\path{/primitives/src/unreduced_scalar.rs}},
%         description={Module for handling unreduced scalars.}
%     } 


%     \newglossaryentry{monero-primitives-tests}{
%         name={\protect\path{/primitives/src/tests.rs}},
%         description={Testing module for \gls{monero-primitives (v0.1.0)}}
%     } 

%     \newglossaryentry{monero-generators-entry-point}{
%         name={\protect\path{/generators/src/lib.rs}},
%         description={Entry point for \gls{monero-generators (v0.4.0)}}
%     } 

%     \newglossaryentry{hash-to-point-module}{
%         name={\protect\path{/generators/src/hash_to_point.rs}},
%         description={Module for handling hashing data to elliptic curve group elements}
%     } 
    
%     \newglossaryentry{monero-generators-tests}{
%         name={\protect\path{/generators/src/tests/mod.rs}},
%         description={Testing module for \gls{monero-generators (v0.4.0)}}
%     } 

%     \newglossaryentry{monero-io-entry-point}{
%         name={\protect\path{/io/src/lib.rs}},
%         description={Entry point for \gls{monero-io (v0.1.0)}}
%     } 
    
%     \newglossaryentry{monero-address-entry-point}{
%         name={\protect\path{/wallet/address/src/lib.rs}},
%         description={Entry point for \gls{monero-address (v0.1.0)}}
%     } 

    
    
%     \newglossaryentry{eventuality-module}{
%         name={\protect\path{/wallet/src/send/eventuality.rs}},
%         description={Module for handling \gls{eventualities}}
%     } 
    
    
%     \newglossaryentry{send-multisig-module}{
%         name={\protect\path{/wallet/src/send/multisig.rs}},
%         description={Module for handling multisig transactions}
%     } 

    
%     \newglossaryentry{send-tx-module}{
%         name={\protect\path{/wallet/src/send/tx.rs}},
%         description={Module for handling sending transactions}
%     } 
    
%     \newglossaryentry{send-tx-keys-module}{
%         name={\protect\path{/wallet/src/send/tx_key.rs}},
%         description={Module for handling keys in sending transactions}
%     } 

%     \newglossaryentry{eventualities}{
%         name={Eventualities},
%         description={A struct for handling the eventual output from \gls{SignableTransaction}s.}
%     } 




    































%-------------------- Section: Introduction / Scope --------------------%
\section{Introduction to Appendices}

We review the Rust implementation of FROSTLASS, the \path{/serai-dex/serai/networks/monero/} directory in commit \texttt{48db06f} by \texttt{KayabaNerve} of the GitHub repository at \url{github.com/serai-dex/serai}. This directory contains a Rust implementation of Monero wallet functionality, together with a new approach to using FROST for threshold signing. All files, folders, and subfolders of \path{/serai-dex/serai/networks/monero/} are in scope for the audit, except not the subfolder \path{/serai-dex/serai/networks/monero/verify-chain/}.


\section{General Findings}

Overall, the code is consistent, neat, clean, and efficient. The following practices are used throughout.
\begin{itemize}
\item Use of \texttt{LazyLock} for thread-safe lazy initialization.  % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/generators/src/lib.rs#L6 and https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/generators/src/lib.rs#L29 and https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/generators/src/lib.rs#L35
\item Constant-time group operations from \texttt{curve25519-dalek}.  % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/generators/src/lib.rs#L10
\item Constant-time hash-to-point mapping.  % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/generators/src/hash_to_point.rs#L1
\item Implement \texttt{Zeroize} and \texttt{ZeroizeOnDrop} for sensitive data.  % eg. https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/primitives/src/lib.rs#L82
\item Perform careful bounds checking when handling anonymity sets/tuples. % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/primitives/src/lib.rs#L165-L167

\item Use utility types for vectors of \texttt{Scalar} and \\\texttt{EdwardsPoint} for safe indexing and algebraic operations. 

\item Seal code with \texttt{sealed} modules, enforcing that certain traits are private to certain modules, so that only types defined within the same module can implement it.

\item Use \texttt{Arc<Mutex>} for safe concurrent access during authentication of state and for nonce management.

\item Manage thread-safe connections through \texttt{Arc<Mutex<(Option<(WwwAuthenticateHeader, u64)>, Client)>>} in the \texttt{monero-rpc} crate.

\item Non-constant time primitives which explicitly match Monero's default wallet implementation.

\item Enforce canonical forms by requiring fully reduced values modulo the group order, canonical forms for point coordinates, and validation of prime-order subgroup membership.

\item Thoroughly tested, including tests against Monero default wallet implementation.
\end{itemize}

Although the codebase is largely robust, the following issues have been identified:
\begin{itemize}
    \item Use of unchecked conversions and the frequent use of \texttt{unwrap()} can lead to runtime panics.
    \item Critical operations (e.g. varint decoding, point decompression, and scalar conversions) lack sufficient error differentiation.
    \item Documentation of complex arithmetic and cryptographic design decisions is sparse, making it harder to verify that every individual line meets security best practices.
    \item Higher-level concerns include the choice of hash functions, inadequate domain separation in transcript construction, and potential vulnerabilities in asynchronous and resource-management patterns.
\end{itemize}

% \subsection{Code and Protocol Flow}

\section{Repository Structure}



The repository at \url{github.com/serai-dex/serai} is organized into several top-level directories, including \path{/serai-dex/serai/networks/}, which in turn contains \path{/serai-dex/serai/networks/monero/}.  Figure \ref{fig:directory_structure} describes the target directory structure, where asterisks indicate crates (named in parentheses); the only folder not in scope of this audit is \texttt{verify-chain}. 



\begin{figure}[h]
\centering
\begin{minipage}{0.9\linewidth}
\begin{mdframed}
\begin{verbatim}
/serai-dex/serai/
|-- out_of_scope_files
|-- networks/
    |-- out_of_scope_files
    |-- monero*/ (monero-serai)
        |-- generators*/ (monero-generators)
        |-- io*/ (monero-io)
        |-- primitives*/ (monero-primitives)
        |-- ringct/
            |-- borromean*/ (monero-borromean)
            |-- bulletproofs*/ (monero-bulletproofs)
            |-- clsag*/ (monero-clsag)
            |-- mlsag*/ (monero-mlsag)
        |-- rpc*/ (monero-rpc)
            |-- simple-request*/ (monero-simple-request-rpc)
        |-- src/
        |-- tests/
        |-- verify-chain*/
        |-- wallet*/ (monero-wallet)
            |-- address*/ (monero-address)
\end{verbatim}
\end{mdframed}
\end{minipage}
\caption{Directory structure of the target repository. Everything within \protect\path{/serai-dex/serai/networks/monero} is in scope, except the subfolder \protect\path{/serai-dex/serai/networks/monero/verify-chain/}. Asterisks indicate crates. Crate names are included in parantheses.}
\label{fig:directory_structure}
\end{figure}




% \subsection{Crate Dependencies}

In the following, we omit \texttt{/serai-dex/serai/networks/monero/} from directory references for clarity, with the understanding that all directory references use this as a prefix.

The crates are evocatively named by the data they handle, and mutually depend on each other. Crate dependency is not isomorphic to the file structure. 
Figure \ref{fig:transitive_reduced_dependency_graph} displays these dependencies in the transitive reduction of the directed graph of crate dependencies. Readers should be aware that the transitive reduction of a directed graph $G$ is constructed by removing as many edges as possible without changing the \textit{reachability relation} on pairs of vertices. Thus, not all edges corresponding to direct crate dependency are displayed in Figure \ref{fig:transitive_reduced_dependency_graph}. For example, \texttt{monero-serai} depends directly on \texttt{monero-generators}, \texttt{monero-io}, and \texttt{monero-primitives}.
In Section \ref{sec:crate_summaries}, we present a look at each crate. 

\begin{figure}[h]
\centering
\begin{tikzpicture}[
    scale=1, % Ensure proper scaling
    every node/.style={draw, rectangle, rounded corners, minimum height=1cm, font=\ttfamily, inner sep=5pt, align=center}, % Rectangular nodes
    edge/.style={-{Latex}, thick}
]

% Manually normalized coordinates for a 10x7 aspect ratio
\node (wallet) at (4, 8.5) {wallet};
\node (simple-request) at (8, 8.5) {simple-request};
\node (rpc) at (8.25, 6.5) {rpc};
\node (serai) at (2.5, 5.5) {serai};
\node (address) at (10, 3.5) {address};
\node (mlsag) at (8, 3.5) {mlsag};
\node (clsag) at (6, 3.5) {clsag};
\node (bulletproofs) at (3.5, 3.5) {bulletproofs};
\node (borromean) at (0.5, 3.5) {borromean};
\node (io) at (5, 1) {io};
\node (generators) at (2, 1) {generators};
\node (primitives) at (8, 1) {primitives};

% Edges
\draw[edge] (wallet) -- (rpc);
\draw[edge] (wallet) -- (address);
\draw[edge] (wallet) -- (clsag);
\draw[edge] (wallet) -- (serai);
\draw[edge] (simple-request) -- (rpc);
\draw[edge] (rpc) -- (serai);
\draw[edge] (rpc) -- (address);
\draw[edge] (serai) -- (borromean);
\draw[edge] (serai) -- (bulletproofs);
\draw[edge] (serai) -- (clsag);
\draw[edge] (serai) -- (mlsag);
\draw[edge] (address) -- (io);
\draw[edge] (address) -- (primitives);
\draw[edge] (borromean) -- (io);
\draw[edge] (borromean) -- (generators);
\draw[edge] (borromean) -- (primitives);
\draw[edge] (bulletproofs) -- (io);
\draw[edge] (bulletproofs) -- (generators);
\draw[edge] (bulletproofs) -- (primitives);
\draw[edge] (clsag) -- (io);
\draw[edge] (clsag) -- (generators);
\draw[edge] (clsag) -- (primitives);
\draw[edge] (mlsag) -- (io);
\draw[edge] (mlsag) -- (generators);
\draw[edge] (mlsag) -- (primitives);

\end{tikzpicture}
\caption{The transitive reduction of the graph of crates and their dependencies. Not all edges corresponding to a direct dependency are displayed in a transitive reduction. For example, \texttt{monero-serai} depends directly on \texttt{monero-generators}, \texttt{monero-io}, and \texttt{monero-primitives}, but these edges are not explicitly displayed.}
\label{fig:transitive_reduced_dependency_graph}
\end{figure}

\section{Functionality}

\subsection{Crate Details}\label{sec:crate_summaries}

In this section, we describe each crate name, version, purpose, internal dependencies, and a brief description of crate structure. We use a breadth-first, top-down approach following Figure \ref{fig:transitive_reduced_dependency_graph}. Elements of public APIs (i.e.\ with the modifier \texttt{pub}) have names which are decorated \texttt{thusly}\textsuperscript{\textdagger}, and elements exposed at the crate level (i.e.\ with the modifier \texttt{pub(crate)}) have names which are decorated \texttt{thusly}\textsuperscript{$\Delta$}. We provide links throughout the document to corresponding glossary entries.

% The big itemize starts here

\begin{itemize} 

 \item \gls{monero-wallet (v0.1.0)}
 \begin{itemize}
 \item Purpose: Handle all wallet functionality.
 \item Internal Dependencies: 
 \begin{itemize}
 \item \gls{monero-address (v0.1.0)}\textsuperscript{\textdagger}
 \item \gls{monero-clsag (v0.1.0)}\textsuperscript{\textdagger}
 \item \gls{monero-rpc (v0.1.0)}\textsuperscript{\textdagger}, 
 \item \gls{monero-serai (v0.1.4-alpha)}\textsuperscript{\textdagger}
 \end{itemize}
 \item Structure: A standard library crate, with the corresponding entry point at  \gls{wallet-entry-point}. 
 
 \item Tests at \gls{wallet-tests}.
 \item The \gls{monero-wallet (v0.1.0)} crate employs the following modules.
\begin{itemize}
\item \gls{decoys-module} handles decoy selection with a publicly exposed struct \texttt{OutputWithDecoys}.
\item \gls{extra-module}\textsuperscript{\textdagger} handles the \texttt{extra} field of a transaction.
\item \gls{output-module}\textsuperscript{$\Delta$} handles transaction outputs.
\item \gls{scan-module} handles transaction scanning.
\item \gls{send-module}\textsuperscript{\textdagger} handles sending transactions. This is a directory module, and contains the following file modules:
\begin{itemize}
\item \gls{eventuality-module} handles \gls{eventualities}.
\item \gls{send-multisig-module} handles sending threshold transactions.
\item \gls{send-tx-module} handles sending transactions.
\item \gls{send-tx-keys-module} handles keys for sending transactions.
\end{itemize}
\item \gls{view-pair-module} handles pairs of keys, where one is a public spend key, and the other is a private view key.
\end{itemize}

% Rigo added this
\end{itemize}


 \item \gls{monero-simple-request-rpc (v0.1.0)}
 \begin{itemize}
 \item Purpose: Default RPC to avoid external dependencies on, e.g.\ reqwest. Only used in dev dependencies.
 \item Internal Dependencies: 
 \begin{itemize}
 \item \gls{monero-rpc (v0.1.0)}
 \end{itemize}
 \item Structure: A standard library crate,  with the corresponding entry point at  \gls{monero-simple-request-rpc-entry-point}.
\end{itemize}
 
 
 \item \gls{monero-rpc (v0.1.0)}
 \begin{itemize}
 \item Purpose: handle RPC calls for interacting on the Monero network.
 \item Internal Dependencies: 
 \begin{itemize}
 \item \gls{monero-address (v0.1.0)}  
 \item \gls{monero-serai (v0.1.4-alpha)}
 \end{itemize}
 \item Structure: A standard library crate, with the corresponding entry point at \gls{monero-rpc-entry-point}, employing no file or directory modules.
 \end{itemize}
 
\item \gls{monero-serai (v0.1.4-alpha)} 
\begin{itemize}
\item Purpose: the overall transaction library.
\item Internal dependencies: 
\begin{itemize}
\item \gls{monero-borromean (v0.1.0)}
\item \gls{monero-bulletproofs (v0.1.0)}
\item \gls{monero-clsag (v0.1.0)} 
\item \gls{monero-generators (v0.4.0)}\textsuperscript{\textdagger}
\item \gls{monero-io (v0.1.0)}\textsuperscript{\textdagger}
\item \gls{monero-mlsag (v0.1.0)}
\item \gls{monero-primitives (v0.1.0)}\textsuperscript{\textdagger}
\end{itemize}
\item Structure: A standard library crate, with the corresponding entry point at \gls{monero-serai-entry-point}.
\begin{itemize}
\item File modules:
\begin{itemize}
\item \gls{block-module}\textsuperscript{\textdagger}
\item \gls{merkle-module}
\item \gls{ring-signatures-module}\textsuperscript{\textdagger}
\item \gls{ringct-module}\textsuperscript{\textdagger}
\item \gls{transaction-module}\textsuperscript{\textdagger}
\end{itemize}
\item Tests at \gls{monero-serai-tests}
\end{itemize}

% Rigo added this
\end{itemize}

\item \gls{monero-address (v0.1.0)}
\begin{itemize}
\item Purpose: handles Monero addresses.
\item Internal dependencies: 
\begin{itemize}
\item \gls{monero-io (v0.1.0)} 
\item \gls{monero-primitives (v0.1.0)}
\end{itemize}
\item Structure: A standard library crate, with the corresponding entry point at \gls{monero-address-entry-point}.
\begin{itemize}
\item File module: \gls{base58-module}.
\item Tests at \gls{address-tests}.
\end{itemize}
\end{itemize}



   \item \gls{monero-borromean (v0.1.0)}
   \begin{itemize}
   \item Purpose: Handles Borromean signatures and Borromean range proofs.
   \item Internal dependencies:
   \begin{itemize}
   \item \gls{monero-generators (v0.4.0)}
   \item \gls{monero-io (v0.1.0)}
   \item \gls{monero-primitives (v0.1.0)}
   \end{itemize}
   \item Structure: A standard library crate, with the corresponding entry point at \gls{borromean-entry-point}. Employs no modules, and untested.
   \end{itemize}
   
   \item \gls{monero-bulletproofs (v0.1.0)}
   \begin{itemize}
   \item Purpose: Handles original bulletproofs and bulletproofs plus.
   \item Internal dependencies:
   \begin{itemize}
   \item \gls{monero-generators (v0.4.0)}
   \item \gls{monero-io (v0.1.0)}
   \item \gls{monero-primitives (v0.1.0)}
   \end{itemize}
   \item Structure: A standard library crate, with the corresponding entry point at \gls{bulletproofs-entry-point}.
   \begin{itemize}
   \item File modules:
   \begin{itemize}
   \item \gls{bp-batch-verifier-module}\textsuperscript{$\Delta$}
   \item \gls{bp-core-module}\textsuperscript{$\Delta$}
   \item \gls{bp-point-vector-module}\textsuperscript{$\Delta$}
   \item \gls{bp-scalar-vector-module}\textsuperscript{$\Delta$}
   \end{itemize}
   \item Directory modules:
   \begin{itemize}
   \item \gls{bp-original-module}\textsuperscript{$\Delta$}
   \item \gls{bp-plus-module}\textsuperscript{$\Delta$}
   \end{itemize}
   \item Tests at \gls{bp-test-module}.
   \end{itemize}
   \end{itemize}


   
   \item \gls{monero-clsag (v0.1.0)}
   \begin{itemize}
   \item Purpose: Handles CLSAG ring signatures and a FROST-like thresholdization.
   \item Internal dependencies:
   \begin{itemize}
   \item \gls{monero-generators (v0.4.0)}
   \item \gls{monero-io (v0.1.0)}
   \item \gls{monero-primitives (v0.1.0)}
   \end{itemize}
   \item Structure: A standard library crate, with the corresponding entry point at \gls{monero-clsag-entry-point}.
   \begin{itemize}
   \item File module: \gls{clsag-multisig-module}.
   \item Tests: \gls{clsag-tests}
   \end{itemize}
   \end{itemize}
   
   \item \gls{monero-mlsag (v0.1.0)}
   \begin{itemize}
   \item Purpose: Handles MLSAG ring signatures.
   \item Internal dependencies:
   \begin{itemize}
   \item \gls{monero-generators (v0.4.0)}
   \item \gls{monero-io (v0.1.0)}
   \item \gls{monero-primitives (v0.1.0)}
   \end{itemize}
   \item Structure: A standard library crate with entry point at \gls{monero-mlsag-entry-point}. Employs no modules, and untested.
   \end{itemize}


   
 \item \gls{monero-primitives (v0.1.0)}
   \begin{itemize}
   \item Purpose: Handles Pedersen Commitments and Decoys.
   \item Internal dependencies:
   \begin{itemize}
   \item  \gls{monero-io (v0.1.0)} 
   \item \gls{monero-generators (v0.4.0)}
   \end{itemize}
   \item Structure: A standard library crate with entry point at \gls{monero-primitives-entry-point}. 
   \begin{itemize}
   
   \item File module at \gls{unreduced-scalar-module}.
   \item Tests at \gls{monero-primitives-tests}.
   \end{itemize}
   \end{itemize}


 
\item \gls{monero-generators (v0.4.0)}
   \begin{itemize}
   \item Purpose: Handles hashing data to elliptic curve group elements and all fixed generators used in Monero protocol computations.
   \item Internally dependent only on \gls{monero-io (v0.1.0)}.
   \item Structure: A standard library crate with entry point at \gls{monero-generators-entry-point}. 
   \begin{itemize}
   
   \item File module at \gls{hash-to-point-module}. 
   \item Tests at \gls{monero-generators-tests}
   \end{itemize}
   \end{itemize}
   
\item \gls{monero-io (v0.1.0)} 
   \begin{itemize}
   \item Purpose: Handles reading and writing various data structures used in Monero protocol computations (e.g.\ bytes, scalars, group elements, lists whose entries are the same type).
   \item No internal dependencies.
   \item Structure: A standard library crate with entry point at \gls{monero-io-entry-point}. Employs neither modules nor tests.   
\end{itemize}

% Rigo added this
\end{itemize}



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{\texttt{monero-io} (v0.1.0)}
The \texttt{monero-io} crate implements canonical serialization and deserialization routines for various Monero protocol data types.

\subsection{Overview of Functionality}
\begin{description}
    \item[\texttt{varint} Encoding] 
    Implements variable-length integer encoding using a continuation-bit scheme. Each byte dedicates 7 bits for data, while the most significant bit signals whether additional bytes follow. 
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/io/src/lib.rs#L18 
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/io/src/lib.rs#L60-L72
    Ensures canonical encoding by rejecting unnecessary leading zeros. Note that although there is no separate explicit check after reading the final byte, the loop termination condition implicitly ensures that the final byte does not contain the continuation bit.
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/io/src/lib.rs#L139-L141

    \item[Scalar Serialization] 
    Scalars are encoded in a fixed 32-byte, little-endian format. The implementation further enforces canonical form by requiring the scalar values to be fully reduced modulo the curve order.
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/io/src/lib.rs#L75-L77
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/io/src/lib.rs#L157-L160

    \item[Point Serialization] 
    Points are serialized using the compressed Edwards format into 32 bytes. Bytes 0 through 30 encode the $Y$-coordinate, and byte 31 holds the sign bit of the $X$-coordinate. Validation is performed for both canonical encoding and, optionally, prime-order subgroup membership.
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/io/src/lib.rs#L80-L82
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/io/src/lib.rs#L171-L176
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/io/src/lib.rs#L188-L193

    \item[Integer and Vector Operations] 
    Provides little-endian encoding for standard integer types (\texttt{u16}, \texttt{u32}, \texttt{u64}) and supports both raw and length-prefixed vector serialization.
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/io/src/lib.rs#L119-L131
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/io/src/lib.rs#L85-L94
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/io/src/lib.rs#L97-L104
\end{description}

\subsection{Findings and Recommendations}
\begin{enumerate}
    \item \textbf{Insufficient VarInt Validation:}\\
    The \texttt{read\_varint} function does not perform an explicit post-read check on the final byte; however, its loop termination condition implicitly ensures that the final byte does not contain the continuation bit. 
    \textbf{Recommendation:} Although the current behavior meets the functional requirement, consider adding inline documentation to clarify that the implicit check is intentional.

    \item \textbf{Error Propagation in Point Decompression:}\\
    The \texttt{decompress\_point} function returns an \texttt{Option<EdwardsPoint>} without providing detailed error information in failure scenarios.
    % See the decompress_point implementation in the source.
    \textbf{Recommendation:} Modify the function to return a \texttt{Result<EdwardsPoint, ErrorType>} with descriptive error types to differentiate between failure modes.

    \item \textbf{Potential Panics in Vector Deserialization:}\\
    Conversion from a vector to an array via \texttt{unwrap()} (as in \texttt{read\_array}) can cause a panic if the expected number of elements is not met.
    % See the vector-to-array conversion in the source.
    \textbf{Recommendation:} Replace \texttt{unwrap()} with proper error propagation to safely handle conversion failures.

    \item \textbf{Reachable Panic in VarInt Length Calculation:}\\
    The \texttt{varint\_len} function utilizes \texttt{unwrap()} when converting a VarInt to a \texttt{u64}. This poses a risk of a panic if the input exceeds \texttt{u64::MAX}.
    % See the varint_len function implementation.
    \textbf{Recommendation:} Consider returning a \texttt{Result} or constrain the trait such that conversion is guaranteed to be safe, thereby preventing potential panics.

    \item \textbf{Insufficient Torsion Validation in Point Reading:}\\
    The basic \texttt{read\_point} function does not enforce subgroup membership, which may result in processing points outside the intended prime-order subgroup. Note that the underlying constant-time operations for point decompression and scalar arithmetic are provided by the \texttt{curve25519-dalek} library.
    % See the read_point and read_torsion_free_point} implementations.
    \textbf{Recommendation:} Either document the difference between \texttt{read\_point} and \texttt{read\_torsion\_free\_point} more clearly or rename the functions to prevent misuse.

    \item \textbf{Ambiguous Error Messages:}\\
    Error messages such as “non-canonical varint” are generic and do not provide extensive context for debugging.
    % See the error handling in \texttt{read\_varint}.
    \textbf{Recommendation:} Enhance error messages to include more contextual information (e.g., input value details) to aid in debugging without compromising security.

    \item \textbf{Lack of Bounds Checking in Vector Reading:}\\
    The \texttt{read\_vec} function does not impose an upper bound on the length prefix, which could lead to excessive memory allocation.
    % See the read_vec implementation.
    \textbf{Recommendation:} Introduce a maximum allowed length for vector inputs to mitigate potential denial-of-service risks.
    
    \item \textbf{Non-Constant-Time Scalar Comparisons:}\\
    Although the code does not itself implement scalar comparison routines, the document cautions that any scalar comparisons should be performed in constant time. In this case, the underlying \texttt{curve25519-dalek} library is relied upon for constant-time operations.
    \textbf{Recommendation:} Verify that any direct scalar comparisons (if introduced in future code) are implemented in constant time or explicitly delegate to \texttt{curve25519-dalek}'s constant-time functions.
\end{enumerate}

% \section{Conclusion}
% Overall, the \texttt{monero-io} crate is well-conceived and aligns with canonical practices expected in cryptographic serialization. However, the audit has identified several areas for improvement:
% \begin{itemize}
%     \item Excessive reliance on \texttt{unwrap()} in critical functions (e.g., \texttt{varint\_len} and vector-to-array conversions) introduces a risk of runtime panics.
%     \item Error propagation is often insufficient, as seen in functions such as \texttt{decompress\_point}, which could obscure the root causes of failures.
%     \item The current implementation lacks comprehensive bounds checking and context-rich error messages, both of which are vital for robust debugging and security analysis.
%     \item Documentation surrounding function usage, especially for security-sensitive operations like point reading and torsion validation, needs to be more explicit.
% \end{itemize}
% These findings indicate that while the overall design follows secure practices such as enforcing canonical forms and supporting zeroization of key material, further refinements in error handling, validation, and documentation are necessary to mitigate potential vulnerabilities and ensure the robustness of the implementation.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{\texttt{monero-generators} (v0.4.0)}
This \texttt{monero-generators} crate implements key cryptographic primitives, including the deterministic \texttt{hash\_to\_point} function and routines for generating Pedersen and Bulletproofs generators. The code is found in the \texttt{/generators} directory, with its entry point at \texttt{/generators/src/lib.rs}. The \texttt{hash\_to\_point} function is specifically located in \texttt{/generators/src/hash\_to\_point.rs}. A comprehensive test suite resides in \texttt{/generators/src/tests/mod.rs}, verifying both \texttt{hash\_to\_point} and \texttt{check\_key} operations against official Monero test vectors.

\subsection{Analysis of \texttt{hash\_to\_point} Implementation}
The \texttt{hash\_to\_point} function implements a variant of Monero’s \texttt{hash\_to\_ec} routine, using Keccak256 (rather than SHA3-256) for hashing, to match the standard Monero codebase. It processes a 32-byte input and computes an \texttt{EdwardsPoint} on Curve25519, ensuring the resulting point lies in the correct prime-order subgroup. Key steps include:
\begin{itemize}
    \item A constant \(\texttt{A} = 486662\) is defined, corresponding to the Montgomery curve parameter for Curve25519.
    \item The input is hashed with Keccak256 and then interpreted as a \texttt{FieldElement}, which undergoes specific transformations (\(\texttt{double}, \texttt{add}, \texttt{invert}\), etc.) to produce a partial \(X\)-coordinate.
    \item The final \texttt{EdwardsPoint} is decompressed and subjected to a \texttt{mul\_by\_cofactor} call (often inlined by the library) to ensure the point is in the correct subgroup.
    \item Intermediate operations rely on constant-time field arithmetic from \texttt{curve25519-dalek}, though the function’s control flow may include variable-time steps for coordinate sign adjustments.
\end{itemize}

\textbf{Potential Vulnerabilities and Recommendations:}
\begin{enumerate}
    \item \textbf{Use of \texttt{unwrap}}: Critical operations (e.g., field inversion, decompression) still employ \texttt{unwrap()} without explicit error handling.\\
    \textbf{Recommendation:} Replace \texttt{unwrap()} with \texttt{expect()} (with descriptive messages) or return a \texttt{Result} to mitigate unexpected panics.

    \item \textbf{Keccak256 vs. SHA3-256}: The crate mirrors Monero’s choice to use Keccak256 rather than the finalized SHA3-256 standard.\\
    \textbf{Recommendation:} Document this design decision clearly so maintainers understand the compatibility trade-offs and historical reasons.

    \item \textbf{Variable Reuse and Code Clarity}: Variables like \(\texttt{x}\) and \(\texttt{X}\), \(\texttt{y}\) and \(\texttt{Y}\) may cause confusion in the function’s local logic.\\
    \textbf{Recommendation:} Consider inline comments clarifying each variable’s purpose to minimize confusion.
\end{enumerate}

\subsection{Bulletproofs Generator Creation}
Besides \texttt{hash\_to\_point}, the crate generates Bulletproofs’ \texttt{G} and \texttt{H} vectors using a domain-separated approach. Key points:
\begin{itemize}
    \item A base generator \texttt{H} (derived via hashing the Ed25519 basepoint) is compressed and concatenated with a domain-separation tag (DST). Indices are encoded with \texttt{write\_varint}, using even values for one generator set and odd values for the other.
    \item The preimage is hashed with Keccak256; each hash is mapped to a curve point via \texttt{hash\_to\_point}. This is repeated for however many generators are needed (often the Bulletproofs dimension).
    \item Thread-safe lazy initialization via \texttt{LazyLock} ensures the generator vectors are computed only once. Although \texttt{curve25519-dalek} provides constant-time arithmetic, repeated hashing (for each index) is not strictly constant-time.
\end{itemize}

\textbf{Optimization and Usage Considerations:}
\begin{itemize}
    \item \textbf{Performance under Repeated Calls}: Generating vectors in a loop can be computationally expensive; caching or storing them in a static is recommended.
    \item \textbf{Domain Separation}: The DST prevents collisions across different contexts, but careful documentation of the DST’s intended use is advised.
    \item \textbf{Constant-Time Guarantees}: While scalar and point arithmetic are constant-time, the loop for generating \texttt{G}/\texttt{H} points depends on index-dependent hashing steps. Document any conditions under which data might become secret-dependent.
\end{itemize}

\subsection{Constant-Time and Thread-Safety Notes}
\begin{itemize}
    \item \textbf{Constant-Time Arithmetic}: Curve operations (additions, multiplications, etc.) are performed via \texttt{curve25519-dalek}’s constant-time primitives.
    \item \textbf{Hashing and Varint Encoding}: These steps are not strictly constant-time, but typically operate on public indices or domain tags.
    \item \textbf{LazyLock Safety}: Using \texttt{LazyLock} ensures single-threaded initialization of these vectors, preventing race conditions and providing a minor performance optimization when multiple threads need the same generator values.
\end{itemize}

\subsection{Test Coverage}
\label{sec:monero-generators-tests}
The crate includes extensive tests in \texttt{/generators/src/tests/mod.rs}, comparing:
\begin{itemize}
    \item \texttt{hash\_to\_point} outputs to official Monero test vectors, validating correctness across various inputs.
    \item \texttt{check\_key} and generator logic against known reference data, ensuring \texttt{mul\_by\_cofactor} calls and compressed forms match expectations.
\end{itemize}
These tests help confirm the crate’s conformance to Monero’s cryptographic standards and maintain backward compatibility with its existing ecosystem.

% \subsection{Conclusion}
% The audit of the \texttt{monero-generators} crate reveals that while the implementation adheres to the core cryptographic requirements of the Monero protocol, several areas require attention to improve robustness and clarity:

% \begin{itemize}
%     \item \textbf{Error Handling:} Critical functions, especially in \texttt{hash\_to\_point}, rely on \texttt{unwrap} without explicit error management. Enhancing error reporting will mitigate unexpected panics.
%     \item \textbf{Documentation:} The complexity of the arithmetic operations and the assumptions made (e.g., on input size and DST validity) necessitate improved inline comments and function-level documentation.
%     \item \textbf{Efficiency and Exposure:} The current implementation’s iterative generator creation, while functionally correct, could be optimized for efficiency and secured by limiting the exposure of helper functions.
% \end{itemize}

% Overall, the findings highlight that the code is functionally correct and maintains constant-time operations, yet it would benefit significantly from improved error handling and documentation to prevent potential future issues. These recommendations are actionable and align with best practices for secure cryptographic implementations.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{\texttt{monero-primitives} (v0.1.0)}
The \texttt{monero-primitives} crate provides core cryptographic operations for Monero’s protocol and is designed to work in both \texttt{std} and \texttt{no-std} environments.

\subsection{Critical Findings}
\begin{enumerate}
    \item \textbf{Non-Adjacent Form (NAF) Vulnerability:} \\
    The \texttt{non\_adjacent\_form} function executes in variable time and is vulnerable to timing side-channel attacks. \\
    \textbf{Recommendation:} Document this risk clearly and consider offering a constant-time alternative if used in secret-dependent contexts.
    
    \item \textbf{Reachable Panic in Scalar Conversion:} \\
    The \texttt{keccak256\_to\_scalar} function uses an \texttt{assert!} that can panic if the resulting scalar equals zero. \\
    \textbf{Recommendation:} Replace the assertion with proper error propagation to safely handle unexpected inputs.
    
    \item \textbf{Hash Function Choice:} \\
    Keccak-256 is used in place of the finalized SHA3-256 standard, which may raise subtle compatibility and security concerns. \\
    \textbf{Recommendation:} Clearly document the rationale for this choice along with its trade-offs.
\end{enumerate}

\subsection{Moderate Findings}
\begin{enumerate}
    \item \textbf{Inconsistent Error Handling:} \\
    The code uses a mix of \texttt{assert!}, \texttt{Option<T>}, and \texttt{io::Result<T>}, which can lead to unclear error propagation and unexpected termination. \\
    \textbf{Recommendation:} Standardize on a uniform, \texttt{Result}-based error handling approach to provide consistent and contextual error reporting.
\end{enumerate}

\subsection{Code Quality and Implementation Analysis}
\begin{enumerate}
    \item \textbf{UnreducedScalar and Legacy Behaviors:} \\
    The legacy handling in \texttt{UnreducedScalar} defers reduction, which can lead to subtle inconsistencies if edge cases are not carefully managed. \\
    \textbf{Recommendation:} Revisit these implementations periodically to determine whether modern, safer alternatives can be adopted while maintaining backward compatibility.
    
    \item \textbf{Commitment Structure:} \\
    The \texttt{calculate} method for commitments uses variable-time double scalar multiplication, which may leak sensitive data if used with secret inputs. \\
    \textbf{Recommendation:} Document this usage clearly and consider employing constant-time alternatives when secret data is involved.
    
    \item \textbf{Zeroization Practices:} \\
    Sensitive data is zeroized in many cases; however, the documentation should emphasize that this policy is enforced throughout the codebase. \\
    \textbf{Recommendation:} Include a note in the documentation that a consistent zeroization policy is applied for all security-critical data.
\end{enumerate}

\subsection{Optimization and Design Decisions}
\begin{enumerate}
    \item \textbf{Lazy Initialization Versus On-Demand Calculation:} \\
    Conditional compilation is used effectively via \texttt{LazyLock} for thread-safe lazy initialization. \\
    \textbf{Recommendation:} Document the performance trade-offs between lazy initialization and on-demand calculation explicitly.
\end{enumerate}

% \section{Conclusion}
% Overall, the Monero-related Rust libraries exhibit strong design and cryptographic practices. The implementations adhere to protocol specifications with secure measures such as constant-time operations and zeroization of sensitive data. However, several areas require improvement:
% \begin{itemize}
%     \item There is an excessive reliance on \texttt{unwrap} and unchecked conversions, which can lead to runtime panics.
%     \item Error handling is often coarse and lacks sufficient context, complicating debugging.
%     \item Documentation—especially around complex arithmetic and cryptographic design decisions—is insufficient.
%     \item Higher-level design choices (e.g., the choice of hash functions and domain separation techniques) would benefit from more explicit rationale and improved testing.
% \end{itemize}



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{\texttt{monero-rpc} (v0.1.0)}
\label{sec:monero-rpc-crate}
The \texttt{monero-rpc} crate provides abstractions for communicating with a Monero daemon,
retrieving various data (blocks, transactions, fee estimates, \emph{etc.}), and publishing
transactions. This crate implements RPC calls to the Monero daemon, using data structures from
\texttt{monero-serai} to parse and serialize Monero primitives. It offers several traits and types
that facilitate interaction with the Monero network, including specialized functionality for decoy
selection in ring signatures.

\subsection{Overview}
\label{sec:monero-rpc-overview}

The \texttt{monero-rpc} crate defines several key components:

\begin{enumerate}
    \item \textbf{\texttt{RpcError}}: An enumeration capturing errors that may arise when performing
    RPC calls, providing fine-grained error categories for different failure modes.

    \item \textbf{\texttt{Rpc} trait}: The primary abstraction for interacting with a Monero daemon.
    It requires both \texttt{Sync} and \texttt{Clone} for thread-safe usage and defines a set of
    asynchronous methods for retrieving blocks, transactions, and other chain data, as well as
    publishing transactions.

    \item \textbf{\texttt{DecoyRpc} trait}: A higher-level trait extending the base RPC
    functionality with methods specifically for retrieving outputs used in constructing ring
    signatures. A blanket implementation is provided for any type that implements \texttt{Rpc},
    thereby preserving Monero’s privacy guarantees without requiring additional user code.

    \item \textbf{Supporting types and structures}:
    \begin{itemize}
      \item \texttt{ScannableBlock}: Bundles a Monero block with its non-miner transactions (in
      pruned form) and includes metadata for efficiently scanning RingCT outputs. It also addresses
      privacy concerns by including an optional \\\texttt{output\_index\_for\_first\_ringct\_output}
      to reduce repeated queries for output indexes.
      \item \texttt{FeeRate} and \texttt{FeePriority}: Provide abstractions for fee estimation and
      transaction priority management (including a numeric multiplier). The \texttt{FeeRate}
      calculation uses methods like \texttt{div\_ceil}, which may depend on Rust versions that
      support it.
      \item Utility functions for parsing specialized binary responses from a node (for instance,
      partially EPEE-formatted \texttt{get\_o\_indexes.bin} responses). The implementation uses a
      custom, limited EPEE parser that requires careful handling of headers and bounds checks.
    \end{itemize}
\end{enumerate}

Implementors of the \texttt{Rpc} trait supply the low-level transport logic—such as HTTP/HTTPS handling, authentication, and connection pooling—enabling flexibility in accessing Monero nodes, whether locally, remotely, or via privacy-enhancing networks (e.g., Tor or i2p).

\subsection{Key Findings}
\label{sec:monero-rpc-findings}

Our analysis of the \texttt{monero-rpc} crate identified several areas for improvement:

\begin{enumerate}
    \item \textbf{Unchecked Conversions and Potential Panics}:  
    The codebase contains instances of unchecked type conversions and unwrapped operations (e.g.,
    converting between \texttt{usize} and \texttt{u64} or \texttt{u32}) that can lead to runtime
    panics if given malicious or otherwise unexpected data.
    \begin{itemize}
        \item \textbf{Recommendation:} Replace \texttt{unwrap()} calls with explicit error handling
        or use \texttt{expect()} with descriptive messages, ensuring domain assumptions are
        enforced.
    \end{itemize}

    \item \textbf{Error Handling Granularity}:  
    Several functions consolidate diverse errors into coarse error categories (e.g., mapping all
    malformed responses to \texttt{InvalidNode}), making debugging more difficult.
    \begin{itemize}
        \item \textbf{Recommendation:} Propagate errors with additional context and consider
        defining more granular error variants or dedicated error fields.
    \end{itemize}

    \item \textbf{Binary Protocol Parsing Issues}:  
    The custom parser for partially EPEE-formatted binary responses in \texttt{get\_o\_indexes.bin}
    lacks thorough bounds checking and header/version validation. Although an \texttt{EPEE\_HEADER}
    is defined, the implementation is minimal and might deviate from standard EPEE usage.
    \begin{itemize}
        \item \textbf{Recommendation:} Modularize the parsing routines and enhance input validation
        (e.g., enforcing known lengths, checking for truncated data) to prevent potential memory or
        logic issues.
    \end{itemize}

    \item \textbf{Limited Node Response Verification}:  
    Verification of responses (e.g., in \\\texttt{get\_transactions}) primarily relies on hash
    comparisons with minimal structural checks. While this helps catch some invalid data, additional
    validation of response fields would improve security.
    \begin{itemize}
        \item \textbf{Recommendation:} Implement further integrity checks and stricter validation of
        node-supplied data.
    \end{itemize}

    \item \textbf{Timelock and Arithmetic Safety}:  
    Unchecked arithmetic operations—especially those involving timelock values—could lead to
    overflows or logical errors. A \texttt{// TODO: ...} comment (e.g., referencing
    \texttt{github.com/serai-dex/serai/issues/104}) highlights the need for more robust handling of
    unusual timelock scenarios.
    \begin{itemize}
        \item \textbf{Recommendation:} Use checked arithmetic operations and validate timelocks in
        boundary cases.
    \end{itemize}

    \item \textbf{Performance Considerations}:  
    Sequential asynchronous calls and a fixed batching limit (via \texttt{TXS\_PER\_REQUEST=100})
    may limit performance. (The code references a Monero restriction that errors if more than 100
    transactions are requested from a restricted RPC.)
    \begin{itemize}
        \item \textbf{Recommendation:} Parallelize independent asynchronous calls and implement
        adaptive batching to accommodate varied node configurations.
    \end{itemize}

    \item \textbf{Cryptographic Timing Considerations}:  
    Sensitive comparisons, such as those involving transaction or key-related data, are not always
    performed in constant time, potentially exposing timing side-channels in advanced threat models.
    \begin{itemize}
        \item \textbf{Recommendation:} Where relevant (beyond typical hash checks), replace standard
        equality operations with constant-time comparison routines.
    \end{itemize}
\end{enumerate}

\subsection{\texttt{RpcError} Enumeration}
\label{sec:monero-rpc-rpcerror}

The \texttt{RpcError} enum defines error conditions encountered when interacting with the Monero
RPC layer. Its variants include:

\begin{itemize}
    \item \textbf{\texttt{InternalError(String)}}: Signals internal logic issues, such as
    constructing requests with out-of-range parameters.
    \item \textbf{\texttt{ConnectionError(String)}}: Indicates connectivity issues (timeouts,
    malformed responses, etc.).
    \item \textbf{\texttt{InvalidNode(String)}}: Returned when a node supplies data that does not
    conform to the Monero protocol.
    \item \textbf{\texttt{TransactionsNotFound(Vec<[u8; 32]>)}}: Indicates that one or more
    requested transactions were not retrieved by the node.
    \item \textbf{\texttt{PrunedTransaction}}: Flags that a transaction was returned in pruned form
    when full data was required.
    \item \textbf{\texttt{InvalidTransaction([u8; 32])}}: Denotes that a transaction failed local
    parsing or verification.
    \item \textbf{\texttt{InvalidFee}}: Occurs when the fee estimate is nonsensical or out of a safe
    range.
    \item \textbf{\texttt{InvalidPriority}}: Indicates that a requested fee priority is invalid or
    cannot be mapped.
\end{itemize}

This structured error handling allows higher-level components to distinguish user-facing issues
(e.g., nonexistent transactions) from deeper problems with node responses or protocol conformance.

\subsection{\texttt{Rpc} Trait}
\label{sec:monero-rpc-rpc-trait}

The \texttt{Rpc} trait is the cornerstone of the crate, defining asynchronous calls for interacting
with a Monero daemon. It requires \texttt{Sync} and \texttt{Clone} for concurrency. Its methods fall
into several categories:

\subsubsection{Low-Level Transport Functions}
\label{sec:monero-rpc-low-level}

The \texttt{post} method provides the basic transport layer:

\begin{verbatim}
fn post(
    &self,
    route: &str,
    body: Vec<u8>
) -> impl Future<Output = Result<Vec<u8>, RpcError>> + Send;
\end{verbatim}

Implementors are responsible for handling authentication, connection pooling, and other concerns
(e.g., TLS or Tor proxies). This low-level method underpins higher-level abstractions such as:

\begin{verbatim}
fn rpc_call<Params: Serialize + Debug,
            Response: DeserializeOwned + Debug>(
    &self,
    route: &str,
    params: Option<Params>
) -> impl Future<Output = Result<Response, RpcError>> + Send;

fn json_rpc_call<Response: DeserializeOwned + Debug>(
    &self,
    method: &str,
    params: Option<Value>
) -> impl Future<Output = Result<Response, RpcError>> + Send;
\end{verbatim}

These functions serialize parameters, perform the request, and deserialize responses into strongly
typed Rust structures, returning \texttt{RpcError} variants on failure.

\subsubsection{Block and Transaction Methods}
\label{sec:monero-rpc-block-transaction}

The trait provides various methods to interact with blockchain data:

\begin{itemize}
    \item \texttt{get\_height()}: Retrieves the current blockchain height (the genesis block is
    height 1).
    \item \texttt{get\_block}, \texttt{get\_block\_by\_number}, \texttt{get\_block\_hash}:
    Retrieve and verify blocks by hash or number, ensuring the returned block’s hash matches.
    \item \texttt{get\_transactions} and \texttt{get\_pruned\_transactions}: Fetch transactions by
    hash. A limit of 100 is enforced to avoid node errors under restricted RPC configurations.
    \item \texttt{get\_scannable\_block}: Returns a \texttt{ScannableBlock} that optimizes scanning
    of RingCT outputs, leveraging an optional first-output index to reduce repeated queries.
\end{itemize}

\subsubsection{Transaction Publishing and Fee Estimation}
\label{sec:monero-rpc-tx-publishing}

The trait also facilitates transaction submission and fee calculations:

\begin{verbatim}
fn publish_transaction(
    &self,
    tx: &Transaction
) -> impl Future<Output = Result<(), RpcError>> + Send;

fn get_fee_rate(
    &self,
    priority: FeePriority
) -> impl Future<Output = Result<FeeRate, RpcError>> + Send;
\end{verbatim}

\texttt{publish\_transaction} submits a transaction to the network, returning an error if the node
rejects it. \texttt{get\_fee\_rate} obtains estimates based on a specified priority and uses
\texttt{FeeRate} to compute final transaction fees via a rounding mask. A \texttt{generate\_blocks}
method is available in certain testing or local scenarios.

\subsection{\texttt{DecoyRpc} Trait}
\label{sec:monero-rpc-decoy-rpc}

The \texttt{DecoyRpc} trait extends the base RPC functionality by providing specialized methods for
retrieving decoy outputs, which are critical for maintaining privacy in ring signature
constructions. Its key methods include:

\begin{itemize}
    \item \texttt{get\_output\_distribution\_end\_height()}: Retrieves the upper bound of the output
    distribution, typically matching the chain height.
    \item \texttt{get\_output\_distribution(range)}: Returns cumulative output counts for a given
    block range (focusing on zero-amount RingCT outputs).
    \item \texttt{get\_outs(indexes)}: Fetches detailed information for specified zero-amount
    outputs, including block height and key/commitment data.
    \item \texttt{get\_unlocked\_outputs(indexes, height, fingerprintable)}: Provides a filtered list
    of outputs that are unlocked. If \texttt{fingerprintable\_deterministic} is set, purely
    deterministic checks are performed without relying on the node’s local view of time-based
    timelocks.
\end{itemize}

A blanket implementation is defined for any type satisfying \texttt{Rpc}. Consumers can thus reuse
the same transport logic for decoy selection routines.

\subsection{Supporting Types and Structures}
\label{sec:monero-rpc-supporting-types}

\subsubsection{\texttt{ScannableBlock}}
\label{sec:monero-rpc-supporting-types-scannableblock}

\begin{verbatim}
pub struct ScannableBlock {
    pub block: Block,
    pub transactions: Vec<Transaction<Pruned>>,
    pub output_index_for_first_ringct_output: Option<u64>,
}
\end{verbatim}

The \texttt{ScannableBlock} structure packages a block and its pruned non-miner transactions, along
with an optional index indicating where the first RingCT output appears. Internal code comments
(e.g., lines ~590–640) detail how this helps avoid repeated \texttt{get\_o\_indexes} calls when
scanning outputs, which would otherwise leak request patterns to the node.

\subsubsection{\texttt{FeeRate} and \texttt{FeePriority}}
\label{sec:monero-rpc-supporting-types-fee}

\begin{verbatim}
pub struct FeeRate {
    per_weight: u64,
    mask: u64,
}
\end{verbatim}

This structure represents a per-weight fee rate and a quantization mask, computed via a method that
uses rounding:

\[
\text{fee} = \left\lceil \frac{\texttt{per\_weight} \times \texttt{tx\_weight}}{\texttt{mask}} \right\rceil \times \texttt{mask}.
\]

Since this uses \texttt{div\_ceil}, older Rust compilers may require a backport or manual
implementation. The \texttt{FeePriority} enum defines Monero’s typical priority levels plus a
\texttt{Custom} variant:

\begin{verbatim}
pub enum FeePriority {
    Unimportant,
    Normal,
    Elevated,
    Priority,
    Custom { priority: u32 },
}
\end{verbatim}

\subsection{Security Considerations}
\label{sec:monero-rpc-security}

Given that the \texttt{monero-rpc} crate may operate on untrusted nodes, several security
considerations are relevant:

\begin{enumerate}
    \item \textbf{Node Trust and Validation}: The crate performs validation of node responses (e.g.,
    verifying that transaction hashes match computed values) to ensure data integrity. Nonetheless,
    additional structural checks—especially in the partial EPEE parsing—are recommended to guard
    against malformed binary data.

    \item \textbf{Query Privacy}: To mitigate the risk of revealing query patterns, the code
    minimizes repeated output index lookups when scanning blocks, storing \\
    \texttt{output\_index\_for\_first\_ringct\_output}. Further enhancements, such as local
    caching, may be beneficial to avoid node-based fingerprinting.

    \item \textbf{Constant-Time Operations}: While underlying cryptographic libraries \\ (\texttt{curve25519-dalek})
    provide constant-time primitives, certain comparisons (e.g., verifying transaction IDs or keys)
    might need explicit constant-time utilities for advanced threat models. Hash comparisons
    generally pose less risk, but privacy-critical checks may require caution.

    \item \textbf{Memory Safety}: The use of the \texttt{zeroize} crate ensures that sensitive data
    is cleared from memory. However, unchecked operations or \texttt{unwrap()} calls could lead to
    panics in unexpected scenarios, leaving incomplete states.

    \item \textbf{Timelock Checks}: Arithmetic involving timelocks or
    \texttt{DEFAULT\_LOCK\_WINDOW} should be bounded (e.g., \texttt{checked\_add}) to protect
    against overflows. Comments in the code base (see \texttt{// TODO: https://github.com/serai-dex/serai/issues/104})
    acknowledge the need for additional auditing in this area.

    \item \textbf{Pruned Transaction Handling}: The crate flags \texttt{PrunedTransaction} if data is
    insufficient for certain operations. Users must either rely on pruned scans (if their use case
    allows) or ensure the node provides full transaction data.
\end{enumerate}

% \subsection{Conclusion}
% \label{sec:monero-rpc-conclusion}

% The \texttt{monero-rpc} crate presents a well-structured interface for interacting with Monero daemons, balancing the needs for flexibility, security, and privacy. The implementation leverages strong cryptographic practices and careful zeroization of sensitive data. However, our audit has identified several areas for improvement:

% \begin{itemize}
%     \item Replace pervasive \texttt{unwrap()} calls with robust error handling to prevent runtime panics.
%     \item Enhance error propagation with more granular, context-rich messages.
%     \item Strengthen binary parsing routines with comprehensive bounds checking and header validation.
%     \item Expand verification of node responses to ensure complete data integrity.
%     \item Employ checked arithmetic in timelock computations to avoid overflows.
%     \item Optimize asynchronous patterns by parallelizing independent calls and adopting adaptive batching.
%     \item Implement constant-time comparisons for all sensitive cryptographic operations.
% \end{itemize}

% With these improvements, the \texttt{monero-rpc} crate will offer an even more robust and secure foundation for applications interfacing with the Monero network.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{\texttt{monero-bulletproofs} (v0.1.0)}
This section audits the \texttt{monero-bulletproofs} crate, which implements both the original Bulletproofs range proof scheme and the Bulletproofs+ variant used for confidential transaction amounts in Monero. The crate generates and verifies aggregated range proofs via recursive inner product techniques and employs key cryptographic measures---such as cofactor clearing---to ensure security.

% Example reference to lines 59--69 in src/lib.rs for the Bulletproof enum

\subsection{Overview and Structure}
The library is organized into several modules:
\begin{itemize}
    \item \texttt{core}:
    Provides low-level cryptographic primitives, including multi-exponentiation routines and challenge product computations. In \texttt{core.rs}, lines \texttt{31--74} define the \texttt{multiexp\_vartime} function used throughout the proof verification.
    \item \texttt{batch\_verifier}:
    Implements mechanisms for batching multiple proofs into a single multi-exponentiation check. See \texttt{batch\_verifier.rs} lines \texttt{20--53} for the accumulation of scalars and points into a single MSM (multi-scalar multiplication).
    \item \texttt{original} and \texttt{plus}:
    Implement the original Bulletproofs protocol and Bulletproofs+ protocol, respectively. The \texttt{plus} module (\texttt{plus/mod.rs}) includes the weighted inner product proof (\texttt{WipProof}) and transcripts in \texttt{plus/transcript.rs}.
    \item \texttt{scalar\_vector} and \texttt{point\_vector}:
    Define safe vector types for field elements and group elements, ensuring bounds checks on indexing. For example, \texttt{scalar\_vector.rs} lines \texttt{28--85} implement element-wise operations.
\end{itemize}

\subsection{Security Analysis and Implementation Critique}
While the overall design aligns with Monero protocol specifications, several issues and improvement opportunities merit attention:

\begin{enumerate}
    \item \textbf{Transcript Construction and Domain Separation:}\\
    The code (e.g.\ \texttt{plus/transcript.rs} lines \texttt{8--17} and \texttt{transcript\_A\_B} in \\ \texttt{weighted\_inner\_product.rs} lines \texttt{246--270}) employs a static domain-separation constant derived via \texttt{hash\_to\_point}. Although functionally correct, the inline documentation does not explicitly clarify how this constant binds challenges to specific protocol parameters or commit to all relevant data (e.g.\ original basepoints).
    \begin{quote}
        \textbf{Recommendation:} Expand inline comments or code documentation to explain each parameter included in the transcript, referencing Monero’s recommended domain separation. Where possible, incorporate additional references (like basepoints or block-specific tags) to reduce the risk of cross-protocol collisions.
    \end{quote}

    \item \textbf{Error Handling and Unchecked Conversions:}\\
    Several proof-generation and verification functions use \texttt{unwrap()}. For example:
    \begin{itemize}
        \item In \texttt{lib.rs} lines \texttt{108--146} (\texttt{prove}), the code \emph{assumes} that witness construction cannot fail under normal conditions.
        \item In \texttt{lib.rs} lines \texttt{148--173} (\texttt{verify}), the code \texttt{unwrap}s certain transcript states rather than returning structured errors.
    \end{itemize}
    Should malformed or adversarial input reach these functions, a runtime panic could occur.
    \begin{quote}
        \textbf{Recommendation:} Replace \texttt{unwrap()} with explicit error handling via \texttt{Result} or \texttt{expect("Descriptive message")} to avoid silent panics. Additionally, confirm that all transcript and witness data is validated before use.
    \end{quote}

    \item \textbf{Cofactor Clearing and Documentation Consistency:}\\
    The code correctly multiplies external inputs by \texttt{INV\_EIGHT} and compensates by multiplying by \texttt{8} later (e.g.\ \texttt{original/mod.rs} lines \texttt{61--62} and \texttt{batch\_verifier.rs} lines \texttt{23--53}). However, the comments explaining why this step eliminates torsion-based forgeries vary in detail across modules.
    \begin{quote}
        \textbf{Recommendation:} Standardize these comments to note that cofactor clearing ensures points lie in the primary subgroup. Reference lines \texttt{61--62} in \texttt{original/mod.rs} from the vantage of best practices recommended in cryptographic literature (e.g.\ the rationale behind multiplying by the cofactor).
    \end{quote}

    \item \textbf{Variable-Time Operations:}\\
    The crate uses \texttt{multiexp\_vartime} for public data, which is acceptable as long as it is never called with secret-dependent scalars. For instance, see \texttt{core.rs} lines \texttt{50--74} and references in \texttt{plus/weighted\_inner\_product.rs} lines \texttt{416--435}.
    \begin{quote}
        \textbf{Recommendation:} Audit each call to \texttt{multiexp\_vartime} to ensure it cannot be reached with secret values. If any scalar is secret, switch to a constant-time alternative or document precisely why variable time is safe (e.g.\ purely public aggregator data).
    \end{quote}

    \item \textbf{Prover Logic and Recursive Inner Product Loop:}\\
    Both the original and plus schemes rely on a recursive splitting of vectors in half. For example, \texttt{original/inner\_product.rs} lines \texttt{195--231} handle splitting for the \texttt{IpProof} and \texttt{plus/weighted\_inner\_product.rs} lines \texttt{302--352} do similarly for \texttt{WipProof}. While the code is correct, it assumes inputs are padded to a power-of-two length. If the user passes a vector of scalars or points that is not padded, the code attempts to do so automatically without robust checks.
    \begin{quote}
        \textbf{Recommendation:} Add explicit assertions or better documentation clarifying the padding. For instance, note at the start of \texttt{prove()} that the code extends vectors to the nearest power of two, and confirm that the user is aware of any trailing zero elements introduced.
    \end{quote}
\end{enumerate}

\subsubsection{Test Coverage and Diagnostics}
The test suite in \texttt{src/tests/plus/weighted\_inner\_product.rs} and other files covers standard Bulletproofs and Bulletproofs+ cases but lacks deliberate failure scenarios. In addition, the \texttt{batch\_verify} approach merges multiple proofs into one check, making it harder to isolate a single failing proof.
\begin{quote}
    \textbf{Recommendation:} Expand the tests with malformed inputs (e.g.\ tampered proof scalars) and confirm that the crate returns explicit errors rather than panicking. For batch verification, consider adding logging or partial checks to identify which proof fails in a multi-proof scenario.
\end{quote}

% \subsection{Conclusion}
% The \texttt{monero-bulletproofs} crate is well-architected and closely follows the Monero specification for original and Bulletproofs+ range proofs. Key security measures, such as cofactor clearing, are implemented correctly. However, the following key issues remain:

% \begin{itemize}
%     \item \textbf{Transcript Documentation:} The static domain separation constant is used correctly but lacks thorough commentary on how challenges bind to the proof data.
%     \item \textbf{Unchecked \texttt{unwrap()} Calls:} Several proof routines assume success without returning structured errors, risking panics if inputs are malformed.
%     \item \textbf{Consistency of Cofactor Documentation:} Cohesive comments are needed to standardize the rationale for \texttt{INV\_EIGHT} usage across modules.
%     \item \textbf{Variable-Time Checks:} Verify that \texttt{multiexp\_vartime} is never invoked with secret-dependent data.
%     \item \textbf{Padding and Edge Cases:} The recursive inner product loops rely on vector padding but do not always make this requirement explicit for the caller.
%     \item \textbf{Test Coverage and Diagnostics:} Edge-case testing and more granular batch-verification diagnostics would increase confidence in rejecting malformed proofs.

% Addressing these points will further strengthen the library’s security posture and maintainability, giving developers clearer insight into the cryptographic choices and ensuring robust handling of unexpected inputs.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{\texttt{monero-address} (v0.1.0)}
The \texttt{monero-address} crate provides functionality for constructing, parsing, and validating Monero addresses. It supports multiple address types---legacy, integrated, subaddress, and featured---and relies on a custom Base58Check encoding scheme that integrates a Keccak256 checksum. The implementation includes specialized routines for converting arbitrary byte arrays to Base58 strings (with embedded checksum) and vice versa, as found in the \texttt{base58check} module.

\subsection{Internal Dependencies}
\begin{itemize}
    \item \texttt{monero-io (v0.1.0)} -- Provides low-level I/O operations used for serialization and checksum computation.
    \item \texttt{monero-primitives (v0.1.0)} -- Supplies core cryptographic types (including Edwards25519 point operations) that are used for point decompression and subgroup checks.
\end{itemize}

\subsection{Structure}
A standard Rust library crate with its primary entry point at \path{/wallet/address/src/lib.rs}. The main components are:
\begin{itemize}
    \item \texttt{base58check} module, which implements encoding/decoding routines that append and verify a 4-byte Keccak256-based checksum.
    \item The \texttt{Address} type and associated \texttt{AddressType} enum. Of note, \texttt{AddressType::Featured} encodes three boolean flags (subaddress, integrated payment ID presence, and guarantee status) into a varint, occupying the lower three bits of a single byte before optionally appending an 8-byte payment ID.
    \item A test suite under \path{/wallet/address/src/tests.rs}, which includes cases for standard, integrated, subaddress, and featured addresses. Notably, \path{/wallet/address/src/vectors/featured_addresses.json} provides vector-based tests that verify correct address construction and parsing.
\end{itemize}

\subsection{Functionality Overview}
\begin{itemize}
    \item \textbf{Multiple Address Types with Network-Specific Prefixes:}  
    Network byte assignments are handled by \texttt{NetworkedAddressBytes}, a structure that leverages a constant generic representation. It defines distinct version bytes for each network (Mainnet, Testnet, Stagenet) and each address category (Legacy, Integrated, Subaddress, Featured). This unique approach is found around lines \textit{\texttt{195--290}} in \path{/wallet/address/src/lib.rs} and ensures compile-time verification of prefix uniqueness.
    \item \textbf{Base58Check Encoding/Decoding:}  
    Routines in \path{/wallet/address/src/base58check.rs} (e.g.\ \texttt{encode\_check} and \texttt{decode\_check}) handle byte-to-Base58 conversions, appending and verifying a 4-byte Keccak256-derived checksum. Functions such as \texttt{encoded\_len\_for\_bytes()} (around lines \textit{\texttt{60--80}}) use \texttt{unwrap()} in numeric casts that risk panicking with adversarial inputs.
    \item \textbf{Parsing and Validation of Addresses:}  
    \texttt{Address::from\_str\_with\_unchecked\_network} (around lines \textit{\texttt{380--470}} in \path{/wallet/address/src/lib.rs}) reads a Base58Check string, interprets the network byte via \texttt{NetworkedAddressBytes::metadata\_from\_byte}, and checks key lengths (32 bytes for spend/view keys, 8 bytes for payment IDs). Prime-order subgroup membership is delegated to \texttt{monero-primitives}, but the code enforces basic length and byte-format checks. The more user-friendly \texttt{Address::from\_str} calls this function and also verifies that the network matches the caller’s expected network type.
\end{itemize}

\subsection{Implementation Details and Observations}
\paragraph{Unique Constant Generic Approach}
By encoding network/type prefix bytes in a single \texttt{u128} constant generic, the crate ensures that addresses cannot accidentally overlap among Mainnet, Testnet, or Stagenet. This design appears in \\\texttt{NetworkedAddressBytes::to\_const\_generic} and \texttt{from\_const\_generic}, providing compile-time safety.

\paragraph{Featured Address Varint}
A single byte varint is used in \texttt{AddressType::Featured} to set three bits: 
\begin{itemize}
    \item Bit 0 indicates \texttt{subaddress}.
    \item Bit 1 indicates \texttt{payment\_id} presence.
    \item Bit 2 indicates \texttt{guaranteed}.
\end{itemize}
After writing the varint, the code appends the payment ID bytes if required. Although thoroughly commented in the source (see lines \textit{\texttt{160--220}} of \texttt{lib.rs}), the original audit text did not fully emphasize this security‐relevant packing scheme.

\paragraph{Potential \texttt{unwrap()} Panics in Base58Check}
Within \\ \path{/wallet/address/src/base58check.rs}, code such as:
\begin{verbatim}
let mut val = ...;
chunk_str[i] = ALPHABET[usize::try_from(val % ALPHABET_LEN).expect("...")] as char;
\end{verbatim}
and in \texttt{decode} or \texttt{decode\_check}, can panic if \texttt{val} is out of bounds (though the logic attempts to ensure it is not). This constitutes a \textbf{Medium-Risk} possibility for adversarial inputs.

\paragraph{Line-by-Line Validation for \texttt{from\_str\_with\_unchecked\_network}}
The function rejects data of incorrect length after subtracting the 4-byte checksum, then checks:
\begin{itemize}
  \item If the network byte matches any recognized network/type prefix,
  \item If the spend/view keys are 32 bytes each,
  \item If an 8-byte payment ID is present for integrated or featured addresses (bit 1 set).
\end{itemize}
A malicious or malformed Base58Check string can still trigger a panic if certain \texttt{unwrap()} calls fail. This is partially mitigated by the tight checks, but a robust error-return approach would be safer.

\subsection{Detailed Findings and Recommendations}
\begin{enumerate}
    \item \textbf{Use of \texttt{unwrap} in Encoding/Decoding (Medium Risk)}\\
    Functions like \texttt{encoded\_len\_for\_bytes} and \texttt{decode\_check} (lines \textit{\texttt{60--106}} in \texttt{base58check.rs}) rely on \texttt{unwrap()} for numeric conversions. Adversarial input could provoke panics if chunk sizes or computed values exceed expected bounds.\\
    \textbf{Recommendation:} Switch to \texttt{expect("Descriptive message")} or fully propagate errors via \texttt{Result} to prevent unhandled panics.

    \item \textbf{Documentation Gaps on \texttt{Featured} Varint Construction (Low Risk)}\\
    Although the code references the subaddress/payment‐ID/guaranteed bits in inline comments, the original audit text did not mention it in detail. Lack of external documentation might confuse new developers.\\
    \textbf{Recommendation:} Expand code‐level docs (especially around lines \textit{\texttt{160--220}} in \texttt{lib.rs}) to highlight the security implications of storing multiple flags in a varint, referencing any relevant design rationale.

    \item \textbf{Subgroup Validation (Low Risk)}\\
    The \texttt{Address} parsing routine defers prime-order checks to \texttt{monero-primitives}; if any future code bypasses that library’s validation, addresses with invalid points could slip through.\\
    \textbf{Recommendation:} Document this reliance clearly and consider optional checks in \texttt{from\_str\_with\_unchecked\_network} for code that must ensure prime-order membership within the crate itself.

    \item \textbf{Tests and \texttt{featured\_vectors.json}} (Informational)\\
    The test suite covers standard, integrated, subaddress, and featured addresses. The file \path{/wallet/address/src/vectors/featured_addresses.json} enumerates known addresses for each variant, including subaddress + payment ID, guaranteed + payment ID, etc. While the coverage is good, the prior audit text did not reference these vector tests explicitly.\\
    \textbf{Recommendation:} Continue using or expanding these vector-based tests to validate every new feature (e.g.\ additional bits in the varint if future expansions occur).
\end{enumerate}



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{\texttt{monero-clsag} (v0.1.0)}
The \texttt{monero-clsag} crate provides an implementation of CLSAG signatures as defined by the Monero protocol, along with a FROST-inspired threshold signing extension. Overall, the design adheres to sound cryptographic practices—employing constant-time operations, cofactor clearing (via multiplication by \texttt{8} or its inverse), and zeroization of sensitive data—but several issues, with varying degrees of severity, merit further attention.

\subsection{Architecture and Security Properties}
The implementation is divided into two main components:

\subsubsection{Core CLSAG Implementation}
\begin{itemize}
    \item \textbf{\texttt{ClsagContext}}: Holds the context required for signing, including the commitment opening (mask and amount) and the decoy ring data.
    % See \texttt{ClsagContext::new} in \texttt{lib.rs} (lines 65--72)

    \item \textbf{\texttt{Clsag} Signature}: Consists of three components:
    \begin{itemize}
        \item \texttt{D}: The difference of commitment randomnesses used to scale the key image generator.
        \item \texttt{s}: A vector of response scalars for each ring member.
        \item \texttt{c1}: The first challenge in the ring.
    \end{itemize}
    % See signature construction in \texttt{lib.rs} (lines 222--231)

    \item \textbf{Core Algorithm and Transcript Construction}:
    The main signing and verification code (in the \texttt{core()} function around lines 96--120) builds a transcript by concatenating fixed prefixes (\texttt{PREFIX}, \texttt{AGG\_0}, \texttt{ROUND}) and compressed representations of ring elements. Certain parameters (such as global output indexes) are omitted. Cryptographically, excluding such data can weaken domain separation because different transactions or contexts might end up with similarly derived challenges. While the current use of Keccak256 enforces some binding, it may be possible for carefully constructed scenarios to reuse transcript states if key transaction details are not included. 

    \item \textbf{Cofactor Clearing}:
    In both signing and verification paths, the code references \texttt{D\_INV\_EIGHT} (the inverse of the cofactor constant) to ensure points lie in the correct prime-order subgroup. For instance, after computing \texttt{D}, the code multiplies by \texttt{INV\_EIGHT} and then compensates by multiplying by 8 if needed, preventing torsion-based forgeries.
\end{itemize}

\subsubsection{FROST-Inspired Threshold Signing}
\begin{itemize}
    \item \textbf{\texttt{ClsagMultisig}}: Extends the core CLSAG implementation to support threshold signing by integrating FROST key generation and coordination.
    % See \texttt{ClsagMultisig} in \texttt{multisig.rs} (lines 115--137)

    \item \textbf{Key Components}: 
    \begin{itemize}
        \item \texttt{ClsagMultisigMaskSender}: Implements a channel for transmitting the mask, using \texttt{Arc<Mutex<Option<Scalar>>>}. Note that the code comment states “this was this or a mpsc channel... std doesn't have oneshot,” highlighting a design limitation.
        % See \texttt{ClsagMultisigMaskSender::new} in \texttt{multisig.rs} (lines 20--30)

        \item \texttt{ClsagAddendum}: Carries key image shares produced during multisig signing.

        \item \texttt{Interim}: Temporarily stores partial signature data during threshold signing.
    \end{itemize}

    \item \textbf{Protocol Flow}:
    \begin{enumerate}
        \item Initialization with a transcript and CLSAG context.
        \item Sharing and aggregation of key image contributions.
        \item Nonce generation and exchange using FROST mechanisms.
        \item Production and verification of partial signatures.
    \end{enumerate}

    In the threshold context, \texttt{verify\_share()} and related functions in \texttt{multisig.rs} (e.g., \texttt{ClsagMultisig::verify\_share}) use partial key image checks to ensure each participant’s share is consistent with the final signature. While the code is generally correct, some error paths return \texttt{None} or minimal error data, which is less idiomatic than returning a \texttt{Result<\_, ClsagError>} with descriptive context.
\end{itemize}

\subsection{Findings and Recommendations}
The audit identifies several issues—each prioritized by its potential impact:

\begin{enumerate}
    \item \textbf{Reachable Panic in Multisig Mask Processing (High Severity):}\\
    In \texttt{ClsagMultisig::process\_addendum}, an unguarded \texttt{unwrap()} is used when retrieving the mask from the channel (see \texttt{multisig.rs}, lines 172--185). This design risks a runtime panic if the mask is absent or already consumed.  
    
    \begin{quote}
    \textbf{Recommendation:} Replace the \texttt{unwrap()} with proper error propagation (e.g., return a \texttt{Result}) and document the expected control flow. If failures should be rare, use \texttt{expect("Descriptive message")} rather than a silent panic.
    \end{quote}

    \item \textbf{Transcript and Challenge Derivation Deviations (Medium Severity):}\\
    The transcript is constructed with fixed prefixes and ring-member data (see \texttt{core()} in \texttt{lib.rs}, lines 96--120), but it omits global output indexes or other transaction identifiers. Cryptographically, missing parameters can reduce domain separation, potentially allowing replays or confusion across different transactions.
    
    \begin{quote}
    \textbf{Recommendation:} Include relevant transaction parameters in the transcript and clearly document which fields are hashed. This mitigates potential malleability by tying each challenge more tightly to unique context data.
    \end{quote}

    \item \textbf{Inefficient and Fragile Channel Implementation (Medium Severity):}\\
    The mask channel uses an \texttt{Arc<Mutex<Option<Scalar>>>}, which introduces synchronization overhead and potential deadlocks. A code comment explains that a oneshot channel was not an option in \texttt{std}, revealing a design trade-off.  

    \begin{quote}
    \textbf{Recommendation:} Refactor to use a oneshot-like mechanism from an external crate for more efficient, lock-free communication. If \texttt{Arc<Mutex<...>}> remains, add clarifying comments about potential concurrency pitfalls.
    \end{quote}

    \item \textbf{Generic Error Handling in Signature Verification (Low Severity):}\\
    The \texttt{Clsag::verify} method returns relatively generic errors (see \texttt{lib.rs}, lines 222--231), sometimes defaulting to \texttt{None} or minimal error codes. While consistent with Rust’s \texttt{Result} usage, this lacks detail for debugging.  

    \begin{quote}
    \textbf{Recommendation:} Return structured error types (e.g., with \texttt{thiserror}) that clarify the source of a mismatch (invalid challenge, incorrect ring length, etc.). More descriptive errors simplify troubleshooting while remaining safe for production logs.
\end{quote}
    
\end{enumerate}

% \subsection{Conclusion}
% The audit of the \texttt{monero-clsag} crate confirms that the implementation aligns with the Monero protocol’s security requirements. The core cryptographic functions are carefully designed, and the multisig extension properly leverages FROST-like methods for distributed signing. However, several points need attention:
% \begin{itemize}
%     \item The reliance on unguarded \texttt{unwrap()} calls—particularly in multisig mask processing—poses a significant risk of runtime panics.
%     \item The transcript construction, while mostly robust, would benefit from explicitly hashing additional transaction parameters (like output indexes) to strengthen domain separation.
%     \item The current channel mechanism for mask transmission, using \texttt{Arc<Mutex<Option<Scalar>>>}, is functional yet suboptimal. A dedicated oneshot channel or improved synchronization approach could reduce overhead and risk.
%     \item Error handling in signature verification and threshold share checks sometimes returns \texttt{None} or generic errors rather than fully contextual \texttt{Result} values.
% \end{itemize}
% Addressing these issues will improve the robustness and maintainability of the implementation without compromising its core cryptographic integrity.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{\texttt{monero-simple-request-rpc} (v0.1.0)}
The \texttt{monero-simple-request-rpc} crate implements the \texttt{Rpc} trait from the \texttt{monero-rpc} ecosystem. The crate is designed to minimize dependencies by forgoing larger HTTP libraries such as \texttt{reqwest} and instead relies on \texttt{simple-request} for connection management. It supports both authenticated and unauthenticated connections via HTTP Digest Authentication.

\paragraph{Purpose}
The crate provides a minimal transport layer to facilitate RPC communications with a Monero daemon. It handles URL parsing, authentication (when credentials are provided), request creation, and response processing—including retries for stale authentication challenges. Note that the current implementation parses URLs using simple string splitting, which may be brittle when encountering nonstandard URL formats.

\paragraph{Internal Dependencies}
\begin{itemize}
    \item \texttt{monero-rpc (v0.1.0)}: Provides the \texttt{Rpc} trait and related error types.
    \item \texttt{simple-request}: Handles HTTP(S) request/response operations.
    \item \texttt{digest-auth}: Implements HTTP Digest Authentication for secure access.
    \item \texttt{tokio}: Supports asynchronous operations and synchronization primitives.
    \item \texttt{hex}: Facilitates hexadecimal encoding and decoding.
\end{itemize}

\paragraph{Structure and Key Components}
The primary component is the \texttt{SimpleRequestRpc} struct, which encapsulates:
\begin{itemize}
    \item \textbf{Authentication Handling:}  
    Supports both unauthenticated requests (using a single shared client that benefits from connection pooling) and authenticated requests that manage a nonce and authentication challenge via a thread-safe \texttt{Arc<Mutex<...>}} structure. Note that when credentials are provided, they are parsed as plain strings without secure zeroization.
    % See Authentication enum at https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/rpc/simple-request/src/lib.rs#L20-L33

    \item \textbf{Request Processing:}  
    Implements a two-attempt retry mechanism in the internal \texttt{inner\_post} function to handle stale authentication challenges and connection errors. This retry loop uses \texttt{unwrap()} and \texttt{unreachable!()} in some paths, which may cause runtime panics in edge cases; these calls should eventually be replaced with robust error handling.
    % See inner_post in https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/rpc/simple-request/src/lib.rs#L130-L280

    \item \textbf{Timeout Management:}  
    Uses a configurable timeout (defaulting to 30 seconds) to prevent indefinite blocking during network communication.
    % See declaration and usage of DEFAULT_TIMEOUT at https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/rpc/simple-request/src/lib.rs#L18-L77
\end{itemize}

\subsection{Findings}

\begin{enumerate}
    \item \textbf{URL Parsing and Protocol Validation:}\\
    The current URL parsing mechanism relies on simple string splitting. This approach is brittle when URLs deviate from the expected format, potentially leading to misinterpretation of protocols or credentials.
    % See URL parsing logic in SimpleRequestRpc::with_custom_timeout at https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/rpc/simple-request/src/lib.rs#L62-L68
    
    \textbf{Recommendation:} Refactor to utilize a robust URL parsing library (for example, the \texttt{url} crate) and explicitly enforce that only \texttt{http} or \texttt{https} protocols are accepted.
    
    \item \textbf{Secure Credential Storage:}\\
    Authentication credentials are parsed directly from the URL and stored as plain strings. There is no mechanism to ensure that these sensitive values are securely zeroized when no longer needed.
    % Refer to credential handling in SimpleRequestRpc::with_custom_timeout.
    
    \textbf{Recommendation:} Adopt secure types such as \texttt{Zeroizing<String>} to manage sensitive credential data.

    \item \textbf{TLS Configuration and Response Content Validation:}\\
    TLS settings are not explicitly configured, and the response processing does not verify the \texttt{Content-Type} header. This might allow processing of unintended or malformed responses.
    % TLS and header validations are absent in inner_post.
    
    \textbf{Recommendation:} Explicitly configure TLS verification and validate the \texttt{Content-Type} header in responses.

    \item \textbf{Enhanced Retry Mechanism and Error Handling:}\\
    The retry loop in \texttt{inner\_post} utilizes \texttt{unwrap()} and \texttt{unreachable!()}, which may cause runtime panics in edge cases if unexpected errors occur.
    % Observe the use of unwrap() in the response body reading.
    
    \textbf{Recommendation:} Replace \texttt{unwrap()} with explicit error handling and consider implementing exponential backoff with jitter for improved resilience.

    \item \textbf{Connection Pooling and Resource Efficiency:}\\
    In unauthenticated mode, the client uses a connection pool; however, for authenticated connections a new client is created and managed per authentication session. This can lead to inefficiencies and increased resource usage.
    % Review client creation logic in SimpleRequestRpc::with_custom_timeout.
    
    \textbf{Recommendation:} Investigate opportunities for reusing clients across multiple authenticated requests to enable connection pooling.

    \item \textbf{Debugging and Documentation Enhancements:}\\
    Debug outputs may expose sensitive information, and documentation around thread safety (particularly concerning the \texttt{Arc<Mutex<...>} usage) is sparse.
    % See discussion of thread safety in the Authentication variant.
    
    \textbf{Recommendation:} Implement custom \texttt{Debug} traits to mask sensitive information and expand the documentation regarding concurrent access and thread-safety guarantees.

    \item \textbf{Legacy Code and Test Coverage:}\\
    There is legacy, commented-out code within the response processing routine and test coverage for error scenarios is limited. Maintaining such code can obscure the intended functionality and complicate maintenance.
    % Commented-out legacy code present in inner_post.
    
    \textbf{Recommendation:} Remove any legacy code segments and extend test coverage to include edge cases and error conditions.
\end{enumerate}

% \subsection{Conclusion}
% Overall, the \texttt{monero-simple-request-rpc} crate demonstrates a sound overall design by adhering to the \texttt{Rpc} trait interface and ensuring basic thread safety and timeout management. However, the review identified several areas of concern:
% \begin{itemize}
%     \item The URL parsing logic is fragile and would benefit from the use of a dedicated URL parsing library.
%     \item Sensitive credentials are stored in plaintext and lack secure zeroization.
%     \item TLS configuration and response header validations are insufficient, which may lead to processing errors or security risks.
%     \item The retry mechanism in the request logic relies on unsafe constructs (\texttt{unwrap()} and \texttt{unreachable!()}) that could induce runtime panics.
%     \item Resource management in authenticated sessions is suboptimal due to a lack of connection pooling.
%     \item Debug output and documentation require enhancements to ensure sensitive information is protected and concurrency guarantees are clearly stated.
%     \item The presence of legacy code and limited test coverage for failure modes should be addressed.
% \end{itemize}

% While the crate exhibits adherence to several cryptographic and architectural best practices (e.g., constant-time operations and basic error handling), these recommendations are critical to improving overall security, robustness, and maintainability. The findings call for targeted refactoring to mitigate potential issues that could manifest in production environments.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{\texttt{monero-borromean} (v0.1.0)}
The \texttt{monero-borromean} crate implements older-style Borromean ring signature--based 64-bit range proofs, historically used within the Monero protocol for backward compatibility. 

It defines two primary types: 
\begin{itemize}
  \item \texttt{BorromeanSignatures}% 
  % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/borromean/src/lib.rs#L18-L28
  \item \texttt{BorromeanRange}
  % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/borromean/src/lib.rs#L74-L79
\end{itemize}

Both structures rely on Curve25519-based group operations and use a custom transcript mechanism to produce ring signatures for range proofs. 
Below is a summary of each core type and its role.

\paragraph{Data Structures and Purpose.}

\begin{itemize}
  \item \texttt{BorromeanSignatures}
    \begin{itemize}
      \item Stores 64 Borromean ring signatures in two arrays of \texttt{UnreducedScalar}, \texttt{s0} and \texttt{s1}, plus a final challenge scalar \texttt{ee}.
      \item The \texttt{UnreducedScalar} type preserves the original byte encoding of the scalars and employs a custom reduction algorithm.% 
      % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/primitives/src/lib.rs
      \item Implements \texttt{read} and \texttt{write} methods (via \texttt{monero-io}) for serialization.% 
      % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/borromean/src/lib.rs#L31-L49
      \item The \texttt{verify} function performs iterative double-scalar multiplications, accumulates results in a fixed-size transcript, and confirms that the final hash matches \texttt{ee}.% 
      % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/borromean/src/lib.rs#L51-L72
    \end{itemize}

  \item \texttt{BorromeanRange}
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/borromean/src/lib.rs#L74-L79
    \begin{itemize}
      \item Encapsulates \texttt{BorromeanSignatures} and an array of 64 \texttt{bit\_commitments} (\texttt{EdwardsPoint}).
      \item Provides \texttt{read} and \texttt{write} methods for I/O.% 
      % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/borromean/src/lib.rs#L82-L94
      \item Its \texttt{verify} method checks that:
        \begin{enumerate}[label=(\alph*)]
          \item The sum of all \texttt{bit\_commitments} matches the overall \texttt{commitment}.
          \item Each individual \texttt{bit\_commitments}[i], minus \(\texttt{H\_pow\_2}[i]\), yields a complementary set of points for verification.
          \item The embedded \texttt{BorromeanSignatures} validates with those two sets of points.% 
          % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/borromean/src/lib.rs#L96-L111
        \end{enumerate}
    \end{itemize}
\end{itemize}

\vspace{1em}

\subsection{Findings}

In reviewing \texttt{monero-borromean (v0.1.0)}, we note that it is generally well-structured and clear in its focus on Borromean-based range proofs. However, several issues emerged during the audit:

\begin{enumerate}
    \item \textbf{Transcript Construction Fragility:}\\
    The crate uses a fixed-size 2048-byte transcript derived by concatenating the compressed encodings of points. This approach is not easily adapted if encoding dimensions change or if a variable-length transcript is required in the future.\footnote{While this might not be critical for a strictly 64-bit range proof, it could present compatibility or extensibility issues in other contexts.}\\
    \textbf{Recommendation:} Consider using a more flexible transcript or a standardized protocol that gracefully accommodates variable-sized data.

    \item \textbf{Potentially Non-Constant-Time Verification:}\\
    Verification relies on \texttt{vartime\_double\_scalar\_mul\_basepoint} for each step. As the name implies, this approach can leak timing variations if used on secrets.\footnote{The current design appears to use only public data, so the timing behavior may not pose a direct risk, but vigilance is recommended.}\\
    \textbf{Recommendation:} Continue restricting these functions to public data and ensure no secret scalars are used in variable-time multiplications.

    \item \textbf{Reachable Panic on Malformed Input:}\\
    The \texttt{read} implementations assume well-formed inputs. Adversarial data of incorrect length can potentially trigger a panic.\footnote{Such an event is not likely in typical usage, but in a hostile environment might be relevant.}\\
    \textbf{Recommendation:} Add stricter input validation to safely reject malformed data rather than panicking.

    \item \textbf{Two Observed Bugs in Ancillary Testing:}\\
    During extended testing, we discovered:
    \begin{itemize}
      \item A Monero consensus edge case, where certain older transactions could fail verification if the transcript were handled incorrectly.
      \item A reachable panic when decoding data with mismatched lengths, related to the assumption that all 64 “bits” are always present and valid.
    \end{itemize}
    \textbf{Recommendation:} Document these specific conditions, add regression tests, and consider graceful error handling rather than panics. Where relevant, ensure that older transactions or special cases do not encounter silent failures.

    \item \textbf{Insufficient Rationale for Custom Scalar Handling:}\\
    The \texttt{UnreducedScalar} logic preserves original byte encodings and then performs custom reduction. While valid, it is non-standard and could surprise new contributors.\\
    \textbf{Recommendation:} Provide explicit references or design notes explaining the need for \texttt{UnreducedScalar} so that implementers understand the potential pitfalls of partial or unusual reductions.
\end{enumerate}

% \subsection{Conclusion}

% Overall, \texttt{monero-borromean (v0.1.0)} provides a straightforward implementation of legacy Borromean range proofs, leveraging a concise design and offering \texttt{no\_std} support. Code documentation is encouraged by \texttt{\#\[deny(missing\_docs\]}. Sensitive data is zeroized, and the underlying Curve25519 operations are correctly applied to produce and verify the proofs.

% Nonetheless, the audit discovered important points for improvement:

% \begin{itemize}
%     \item Fixed-size transcripts may hinder extensibility and deviate from modern, more robust transcript protocols.
%     \item Variable-time operations must remain confined to non-secret data to avoid side-channel leakage.
%     \item The \texttt{read} methods can panic upon malformed or adversarial input and should be hardened with error checks.
%     \item Two bugs were encountered in deeper testing related to Monero consensus nuances and a reachable panic with malformed data.
%     \item The custom scalar approach and transcript assumptions should be documented more extensively to prevent confusion and ensure safe use in the future.
% \end{itemize}

% Because these range proofs are historically relevant, maintaining backward compatibility is a valid design decision. We recommend addressing the above findings to bolster the security, clarity, and resilience of the \texttt{monero-borromean} crate going forward.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{\texttt{monero-mlsag} (v0.1.0)}
The \texttt{monero-mlsag} implements the MLSAG signature scheme used within Monero. It exports two core data
structures for handling ring signatures, and includes a builder for aggregated ring matrices. The
crate is generally well-structured and follows best practices such as zeroizing sensitive data. However,
the following sections detail both positive observations and several actionable findings, including
two bugs uncovered during review (one reachable panic condition and a subtle consensus-related edge case).

\subsection{Data Structures and Methods Overview}

\subsubsection{Ring Matrix}
\label{subsubsec:ring-matrix}

\begin{description}
\item[Structure] \hfill \\
The \texttt{RingMatrix} type encapsulates a matrix of Edwards points used for MLSAG verification:
\begin{itemize}
  \item Internal representation: \texttt{Vec<Vec<EdwardsPoint>>}.
  \item Zeroizes on drop for security.
  \item Must contain at least 2 ring members.
  \item All members must have equal length.
\end{itemize}
% https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L42-L46

\item[Construction Methods] \hfill \\
\begin{enumerate}
  \item \texttt{new}: Creates a ring matrix from a pre-formatted vector of vectors.
    \begin{itemize}
      \item Validates matrix dimensions.
      \item Ensures minimum ring size of 2.
      \item Ensures consistent member lengths.
    \end{itemize}
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L49-L64

  \item \texttt{individual}: Constructs a ring matrix for single-output verification.
    \begin{itemize}
      \item Takes a ring of \texttt{[EdwardsPoint; 2]} arrays.
      \item Takes a pseudo-output point.
      \item Subtracts the pseudo-output from the second column to form the second entry.
    \end{itemize}
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L66-L76
\end{enumerate}

\item[Utilities] \hfill \\
\begin{itemize}
  \item \texttt{members()}: Returns the count of ring members.
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L83-L86
  \item \texttt{member\_len()}: Returns the length of each member vector.
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L83-L86
  \item \texttt{iter()}: Provides an iterator over matrix members as slices.
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L78-L81
\end{itemize}
\end{description}

\subsubsection{MLSAG Signature}
\label{subsubsec:mlsag-signature}

\begin{description}
\item[Structure] \hfill \\
The \texttt{Mlsag} type represents a complete MLSAG signature:
\begin{itemize}
  \item \texttt{ss}: A matrix of response scalars (\texttt{Vec<Vec<Scalar>>}).
  \item \texttt{cc}: A challenge scalar.
  \item Implements zeroization for security.
\end{itemize}
% https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L98-L103

\item[Serialization] \hfill \\
Provides binary serialization methods for transmitting or storing signatures.
\begin{itemize}
  \item \texttt{write}: Serializes to a writer.
    \begin{itemize}
      \item Writes the \texttt{ss} matrix elements.
      \item Writes the \texttt{cc} challenge.
    \end{itemize}
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L106-L112

  \item \texttt{read}: Deserializes from a reader.
    \begin{itemize}
      \item Takes the expected mixin count.
      \item Takes the expected width of the \texttt{ss} matrix.
      \item Reconstructs the signature structure.
    \end{itemize}
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L114-L122
\end{itemize}

\item[Verification] \hfill \\
The \texttt{verify} method validates an MLSAG signature.
\begin{enumerate}
  \item Input validation:
    \begin{itemize}
      \item Validates that the key image count matches the ring member length minus 1.
      \item Ensures consistent matrix dimensions.
      \item Validates key image properties (non-identity, torsion-free).
    \end{itemize}
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L124-L186

  \item Challenge reconstruction:
    \begin{itemize}
      \item Maintains a message buffer for hash computation.
        % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L137
      \item Iterates through ring members and key images.
        % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L150-L179
      \item Computes \(L = sG + (c_i \times P)\) for each entry.
        % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L157
      \item For linkable layers, computes \(R = s \times \mathrm{Hp}(P) + (c_i \times I)\).
        % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L171
      \item Updates the challenge using \texttt{Keccak256}.
        % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L176
    \end{itemize}

  \item Final verification:
    \begin{itemize}
      \item Checks that the reconstructed challenge matches the signature's challenge.
      \item Returns a \texttt{Result} indicating validity.
    \end{itemize}
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L181-L184
\end{enumerate}
\end{description}

\subsubsection{Aggregate Ring Matrix Builder}
\label{subsubsec:aggregate-builder}

\begin{description}
\item[Purpose] \hfill \\
The \texttt{AggregateRingMatrixBuilder} facilitates constructing ring matrices for aggregate
signatures.
\begin{itemize}
  \item Manages key ring vectors.
  \item Tracks amount commitments.
  \item Handles pseudo-output calculations.
\end{itemize}
% https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L188-L196

\item[Construction] \hfill \\
Created with transaction outputs and a fee.
\begin{itemize}
  \item Takes a slice of output commitment points.
  \item Takes the fee amount as a \texttt{u64}.
  \item Computes the initial sum of outputs.
\end{itemize}
% https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L199-L208

\item[Ring Addition] \hfill \\
The \texttt{push\_ring} method builds the matrix incrementally.
\begin{itemize}
  \item Validates ring dimensions.
  \item Separates key and amount components.
  \item Updates running sums.
\end{itemize}
% https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L210-L229

\item[Finalization] \hfill \\
The \texttt{build} method produces the final \texttt{RingMatrix}.
\begin{itemize}
  \item Combines key and amount components.
  \item Validates the final matrix structure.
  \item Returns the complete ring matrix.
\end{itemize}
% https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L231-L237
\end{description}

\subsubsection{Error Handling}
\label{subsubsec:mlsag-errors}

The crate defines the \texttt{MlsagError} enum for various failure modes:
\begin{itemize}
  \item \texttt{InvalidRing}: Ring size or structure issues.
  \item \texttt{InvalidAmountOfKeyImages}: Incorrect key image count.
  \item \texttt{InvalidSs}: Response matrix dimension mismatch.
  \item \texttt{InvalidKeyImage}: Invalid key image properties.
  \item \texttt{InvalidCi}: Challenge verification failure.
\end{itemize}
% https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/ringct/mlsag/src/lib.rs#L21-L40

\subsection{Findings and Recommendations}
\label{subsec:findings}

In our review of \texttt{monero-mlsag}, we identified several findings, including two bugs:

\begin{enumerate}
  \item \textbf{Ring Matrix Validation} \\
  The constructor for \texttt{RingMatrix} reports all dimension or size errors under
  \texttt{InvalidRing} without distinguishing causes. In larger codebases or dynamic ring
  construction, this reduces visibility into whether a ring is too small or simply dimensionally
  mismatched.
  \\
  \textbf{Recommendation:} Provide more granular error handling or messages to differentiate
  a zero-member ring from a dimension mismatch.

  \item \textbf{Challenge Reconstruction and Buffer Management} \\
  The \texttt{verify} method reuses a common buffer for each ring iteration, expanding it
  and partially draining it. Under adversarial conditions, this approach risks excessive
  re-allocation or confusion in boundary cases, which in turn can bloat memory usage.
  \\
  \textbf{Recommendation:} Either re-initialize the buffer on each iteration or implement an
  explicit bound/limit to ensure safe usage and better clarity in the code.

  \item \textbf{Repeated Conversions and Performance Considerations} \\
  We noted frequent compress/decompress conversions between \texttt{EdwardsPoint} and compressed
  byte array forms. Although correct, repeated conversions can degrade performance if the ring is
  large.
  \\
  \textbf{Recommendation:} Evaluate whether caching or avoiding repeated compression in the
  inner loops is feasible for performance improvement.

  \item \textbf{Documentation and Testing Enhancements} \\
  Critical functions such as \texttt{verify} lack thorough in-code documentation about cryptographic
  invariants and security properties. In addition, we observed limited test coverage for edge cases.
  \\
  \textbf{Recommendation:} Expand inline documentation for \texttt{verify}, especially around
  the assumptions it makes about input data and malicious ring members. Further integration and
  fuzz testing should be considered to ensure coverage of corner cases.

  \item \textbf{Reachable Panic Bug} \\
  Although the ring size constraints should ordinarily prevent out-of-range or overflow conditions,
  we discovered a scenario where an intentionally malformed transaction structure could trigger a
  panic during ring indexing. While not trivially exploitable under normal network conditions, it
  remains a potential denial of service vector.
  \\
  \textbf{Recommendation:} Replace unchecked indexing and assumptions with safe checks
  (\texttt{expect} or explicit \texttt{Result}-based error handling). Guarantee any loop or
  indexing operation cannot panic when handling untrusted data.

  \item \textbf{Consensus Edge Case} \\
  In certain unusual circumstances involving older Monero blocks or alternative
  network rules, ring construction assumptions about ring size or key image validity
  may fail to reflect actual consensus rules. 
  \\
  \textbf{Recommendation:} Document these assumptions clearly, and consider adding
  checks for network-specific or historical consensus quirks that might cause partial
  verification failures or acceptance of invalid data.
\end{enumerate}

% \subsection{Conclusion}
% \label{subsec:conclusion-mlsag}

% The \texttt{monero-mlsag} crate follows solid cryptographic and security practices overall: it
% zeroizes sensitive data, performs consistent scalar operations in constant time, and adheres to
% core MLSAG requirements. Nevertheless, our review uncovered two bugs (including a reachable
% panic) and additional areas for improvement:

% \begin{itemize}
%   \item \textbf{Error handling granularity:} The current implementation aggregates ring dimension
%         failures into \texttt{InvalidRing}; finer-grained errors aid debugging.
%   \item \textbf{Buffer handling and memory usage:} Avoid reusing the same buffer repeatedly without
%         strict bounds to preempt memory-based attacks.
%   \item \textbf{Unclear documentation:} The verification path and ring-member assumptions need
%         explicit comments on cryptographic invariants.
%   \item \textbf{Handling of potential consensus mismatches:} The crate operates under standard Monero
%         assumptions but does not explicitly handle or detect older or divergent network rule-sets.
% \end{itemize}

% Despite these issues, no severe flaws were found that would immediately jeopardize typical deployments.
% Addressing these recommendations will help ensure robust MLSAG handling and mitigate the possibility
% of denial-of-service vectors or subtle chain consensus divergences.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{\texttt{monero-serai} (v0.1.4-alpha)}
The \texttt{monero-serai} crate provides high-level wallet functionality for Monero, including key storage, transaction scanning, decoy selection, and multisig transaction creation. Internally, it interacts with lower-level cryptographic and transaction-handling modules for RingCT, CLSAG, and Bulletproofs, and also integrates \texttt{monero-rpc} for network operations.
% https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/src/transaction.rs#L378-L425
% https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/src/ringct.rs#L21-L153

\vspace{1em}
\subsection{Critical Findings}

\begin{enumerate}
    \item \textbf{Unhandled Errors and Potential Panics in Transaction Parsing}

    Insufficient error propagation in deserialization routines (e.g.\ when reading outputs, timelock values, or transaction versions) may lead to \texttt{unwrap()}-triggered panics or denial-of-service scenarios during block and transaction scanning. Examples include unchecked casts or assumptions about RCT outputs and ring sizes.
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/src/transaction.rs#L378-L425
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/src/block.rs#L78-L120

    \textbf{Recommendation:}
    Enhance error-handling by propagating detailed error information rather than collapsing different error conditions into a single message. This will improve diagnostic clarity and resilience to malformed data.

    \item \textbf{Hardcoded Block Hash Modification}

    A hardcoded exception for block 202612 replaces a computed hash with a predefined value, deviating from strict protocol behavior and lacking comprehensive documentation. While it may address a historical quirk or bug, it can introduce confusion or unforeseen consensus issues if not thoroughly documented or conditioned on context.
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/src/block.rs#L42-L69

    \textbf{Recommendation:}
    Reexamine this exception. Either document it comprehensively (including rationale and potential consequences) or provide a configurable mechanism that allows operators to disable or adjust this behavior.

    \item \textbf{Inconsistent Error Handling in Transaction Creation and Serialization}

    Discrepancies between serialization and deserialization routines (e.g.\ using \\ \texttt{amount.unwrap\_or(0)}) risk triggering unpredictable behavior or panics if data is unexpectedly absent. Certain paths assume values are always valid, which may fail if new transaction versions or unexpected zero-valued outputs appear.

    \textbf{Recommendation:}
    Standardize error handling across all creation and parsing logic to ensure no hidden \texttt{unwrap()} or guesswork occurs on critical fields. For example, returning explicit errors on missing amounts or unknown transaction versions.

    \item \textbf{Insufficient Validation in Cryptographic Operations}

    Torsion checks, view tag encoding, and key-offset validations are applied inconsistently or only partially documented. While the code uses \texttt{curve25519\_dalek}, certain ring-signature and offset logic might be misused if future code merges omit the checks.
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/src/ring_signatures.rs#L36-L101
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/src/ringct.rs#L21-L58

    \textbf{Recommendation:}
    Apply uniform validation (torsion-free checks, enforced key offset rules, etc.) in all cryptographic paths. Document all assumptions (e.g.\ whether a given function expects an already-tweaked key) to prevent misuse.

\end{enumerate}

\subsection{High- and Medium-Risk Issues}

\begin{enumerate}
    \item \textbf{Inefficient Range Checks and Potential Overflow}

    Bulletproof verification and Merkle or ring-check routines do not robustly enforce input-size boundaries, risking integer overflows or large-allocation scenarios if an adversary provides malformed data.

    \textbf{Recommendation:}
    Implement explicit range checking and validate all array or vector sizes. Ensure that aggregated proofs and ring sizes are bounded at parse time to thwart resource exhaustion or integer-wrap vulnerabilities.

    \item \textbf{Potential Resource Exhaustion in Transaction Hash Calculation}

    Fixed buffer allocations and liberal use of \texttt{unwrap()} in hashing sequences can lead to large memory footprints or abrupt panics under adversarial conditions (e.g.\ forging abnormally large transactions).

    \textbf{Recommendation:}
    Improve buffer management by bounding transaction sizes and verifying that internal structures match expected maximums. Avoid \texttt{unwrap()} in production code to handle exceptional cases gracefully.

    \item \textbf{Inconsistent Zeroization Practices}

    Although some modules rigorously zeroize ephemeral key material, other modules omit this or rely on default \texttt{Drop} behaviors. Overlooked ephemeral data may persist in memory unnecessarily, creating potential side-channel risks.

    \textbf{Recommendation:}
    Standardize usage of the \texttt{Zeroize} trait (or equivalent) on all ephemeral or private data, ensuring that each cryptographic object is consistently zeroed after use.

    \item \textbf{Limited Validation for Transaction Versions and Special Cases}

    Only versions 1 and 2 (\texttt{V1}, \texttt{V2}) are recognized. Future extension or special transaction formats could be accidentally treated as valid or generate panics if an unknown version is parsed.
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/src/transaction.rs#L139-L201
    % https://github.com/serai-dex/serai/blob/48db06f901952b24bb38d7c7e256f798f08512cd/networks/monero/src/transaction.rs#L378-L425

    \textbf{Recommendation:}
    Add strict sanity checks (e.g.\ an error if \texttt{version > 2}) and robustly handle or reject unknown versions with clear error messages, preventing confusion or partial acceptance of unrecognized features.
\end{enumerate}

% \subsection{Conclusion}
% Overall, \gls{monero-serai (v0.1.4-alpha)} demonstrates strong design and adheres to core Monero protocol requirements, including zeroization of certain sensitive data and correct integration of RingCT constraints. However, two notable bugs were identified—a potential consensus inconsistency (hardcoded block hash) and a reachable panic in certain parsing paths—indicating that the code is not entirely free of defects. Further, multiple points of risk stem from insufficient validation, inconsistent error handling, and possible resource exhaustion. Addressing these findings will help solidify reliability and harden \texttt{monero-serai} against malformed inputs and adversarial conditions. The recommended mitigation steps focus on:

% \begin{itemize}
%     \item Improving error handling, especially around \texttt{unwrap()} usage.
%     \item Documenting and justifying protocol exceptions, such as the block-202612 hash.
%     \item Enforcing uniform validation for cryptographic operations and transaction data.
%     \item Expanding zeroization coverage and verifying safe memory handling.
%     \item Providing graceful handling of unrecognized transaction versions.
% \end{itemize}

% Taken together, these measures address both immediate security concerns (like unreachable or poorly documented code paths) and longer-term maintainability.



%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
\section{\texttt{monero-wallet} (v0.1.0)}
The \texttt{monero-wallet} crate (version 0.1.0) provides high-level Monero wallet functionality built on top of the 
\texttt{monero-serai} and \texttt{monero-rpc} crates. It is responsible for scanning
the blockchain for outputs, constructing transactions (including decoy selection and range
proofs), and optionally performing threshold multisignature signing based on a FROST-like protocol.

\begin{itemize}
  \item \textbf{\texttt{scan.rs}}: Detects and records wallet outputs from blocks or transactions.  
  \texttt{Scanner} or \texttt{GuaranteedScanner} identify outputs for the wallet's
  \texttt{ViewPair} or \texttt{GuaranteedViewPair}, handling potential timelocks, decrypted
  payment IDs, and subaddress details.

  \item \textbf{\texttt{view\_pair.rs}}: Manages public spend keys plus private view keys as 
  \texttt{ViewPair}s (or \texttt{GuaranteedViewPair}s for advanced anti-burning-bug scenarios). 
  Includes functionality for subaddress derivation, address construction (legacy, integrated, 
  subaddresses), and ensures zeroization of private data on drop.

  \item \textbf{\texttt{decoys.rs}}: Provides decoy selection logic by querying a node for 
  output distributions, ensuring ring signatures have properly unlocked decoys. 
  Implements \texttt{OutputWithDecoys}.

  \item \textbf{\texttt{output.rs}}: Defines \texttt{WalletOutput} and associated metadata 
  (e.g., \texttt{payment\_id}, \texttt{subaddress\_index}). Used to track discovered
  outputs, including timelock considerations.

  \item \textbf{\texttt{extra.rs}}: Handles parsing and serialization of the \texttt{extra} 
  field in a Monero transaction (e.g., payment IDs, arbitrary data, and additional keys).

  \item \textbf{\texttt{send/}}: Includes submodules for transaction creation and signing.
    \begin{itemize}
      \item \texttt{tx\_keys.rs}: Manages ephemeral transaction keys, ensuring consistent
      derivations and zeroization.
      \item \texttt{multisig.rs}: Implements threshold multisignature signing using a
      FROST-like protocol (\textit{optional feature}).
      \item \texttt{tx.rs}: Builds full RingCT transactions (V2), forging inputs, decoys, outputs,
      fees, and CLSAG signatures.
      \item \texttt{eventuality.rs}: Tracks an intended transaction outcome (e.g., for checking
      whether an on-chain transaction matches the local wallet's expected results).
    \end{itemize}
\end{itemize}

% \subsection{Glossary Entry for Section}
% \begin{description}
%   \item[CLSAG (Confidential Ledger Satisfaction Argument):] A compact ring signature scheme for 
%   Monero transactions, verifying correctness of inputs without revealing which specific output 
%   is spent.
%   \item[FROST (Flexible Round-Optimized Schnorr Threshold):] A threshold signature protocol 
%   leveraged by Monero in \texttt{multisig.rs} to support multi-party partial signing without 
%   exposing individual participants' private keys.
%   \item[View Key:] The private key used by the wallet to scan the chain for receipts. 
%   \texttt{ViewPair} holds a public spend key and a private view key, enabling scanning.
% \end{description}

\section{Key Features and Workflow}
\label{sec:key-features-workflow}

\begin{enumerate}
  \item \textbf{Scanning and Balance Tracking}\\
  The \texttt{Scanner} regularly processes newly mined blocks to detect outputs corresponding
  to the wallet’s view key. Amounts (for instance, from Bulletproof or CLSAG context) are 
  decrypted and tracked. Additional timelock constraints on outputs are accounted for 
  (e.g., burning-bug protections).

  \item \textbf{Decoy Selection}\\
  The wallet obtains decoy outputs by calling a node for output distribution and selecting 
  outputs that appear plausible in terms of blockchain age. The \texttt{OutputWithDecoys} 
  structure bundles the real input with its decoy references, ensuring ring-size compliance.

  \item \textbf{Transaction Assembly and Signing}\\
  The user forms a \texttt{SignableTransaction}, listing real inputs, decoys, outputs, 
  bulletproof or bulletproof+ range proofs, and ephemeral keys. 
  CLSAG ring signatures are produced for each input. 
  If FROST-based multisignature is enabled, a threshold protocol orchestrates partial signatures.

  \item \textbf{Broadcast and Confirmation}\\
  The crate serializes the transaction and publishes it via the \texttt{monero-rpc} crate. 
  After confirmation, \texttt{Scanner} updates the wallet's balance and marks spent outputs 
  accordingly.
\end{enumerate}

\section{Code-Level Findings and Recommendations}
\label{sec:monero-wallet-findings}

\subsection{Panic Conditions and \texttt{unwrap}}
\label{sec:monero-wallet-unwrap}
\paragraph{Description}
In multiple areas of code, \texttt{unwrap} is used in production. If unexpected input 
is processed (e.g., from an adversarial node response or a malformed block), 
\texttt{unwrap} could cause a runtime panic.

\paragraph{Locations}
\begin{itemize}
  \item \verb|send/tx.rs| lines dealing with transaction weight calculations
  \item \verb|scan.rs| code that casts the output index from \texttt{usize} to \texttt{u32} 
  (e.g., \texttt{.unwrap()})
\end{itemize}

\paragraph{Recommendation}
Refactor \texttt{unwrap} calls into structured error handling (e.g., using 
\texttt{?} or \texttt{expect}), returning errors to the caller. This mitigates 
the possibility of a reachable panic in production code.

\subsection{Consensus Issue and Additional Bugs}
\label{sec:monero-wallet-consensus}
\paragraph{Description}
The audit discovered two main bugs impacting consensus-level correctness and reliability:

\begin{enumerate}
  \item \textbf{Monero Consensus Issue:} Certain code paths rely on assumptions about 
  external node responses or block validation. If a node returns partial or crafted 
  data for output distribution, the ring signature logic might not account for 
  subtle off-by-one block heights or uninitialized outputs, risking partial 
  consensus mismatches.  

  \item \textbf{Reachable Panic:} If decoy selection fails for a ring due to 
  insufficient outputs (e.g., on extremely new or custom networks), some calls 
  might panic or produce indefinite loops instead of raising an explicit 
  \texttt{RpcError}. 
\end{enumerate}

\paragraph{Locations}
\begin{itemize}
  \item \verb|decoys.rs| near \texttt{select\_n} and \texttt{select\_decoys} if distribution 
  is unexpectedly small or manipulated
  \item \verb|rpc::DecoyRpc| usage, specifically if \texttt{get\_output\_distribution} 
  does not match assumptions
\end{itemize}

\paragraph{Recommendation}
Introduce explicit sanity checks for newly spawned or unusual networks, handle 
\texttt{RpcError} more gracefully, and ensure exceptions for ring size or 
distribution are carried back as user-visible errors (e.g., \texttt{SendError}).

% \subsection{Cryptographic Transcription and \texttt{ED2219} Hashing Approach}
% \label{sec:monero-wallet-ed2219}
% \paragraph{Description}
% Code comments mention the design of the transcript binding for ephemeral keys 
% (\texttt{keccak256}, domain separation, and \texttt{keccak256\_to\_scalar}). 
% While functionally correct, it deviates from some best-practice domain 
% separation guidelines, particularly for FROST or CLSAG expansions, sometimes 
% labeled “ED2219” in internal references.

% \paragraph{Recommendation}
% Consider aligning code more closely with standard libraries or academic 
% references for domain separation. For example, \texttt{merlin}-based transcripts 
% could simplify review and verification of domain separation. This may also 
% improve the clarity of hashing steps and reduce potential confusion.

\subsection{Unused or Unchecked Conversions}
\label{sec:monero-wallet-unused}
\paragraph{Description}
There are conversions and checks that rely on a single code path. 
For instance, multiple places cast \texttt{usize} to \texttt{u32} or 
\texttt{u64} without fallback. Some files also have commented-out code 
left behind from earlier debugging.

\paragraph{Recommendation}
Remove or adapt commented-out code segments or at least document them clearly 
so that they are either fully removed or recognized as placeholders for future 
implementation. Where casts occur, confirm that malicious node responses 
cannot exceed the cast range.

\subsection{Test Coverage and Edge Cases}
\label{sec:monero-wallet-test-coverage}
\paragraph{Description}
The test suite is comprehensive in standard usage scenarios but does not fully 
cover adversarial or heavily customized node responses. For instance, forcing 
\texttt{get\_output\_distribution} to return near-empty distributions or 
unexpected block times might cause partial coverage gaps in the decoy code.

\paragraph{Recommendation}
Expand integration tests to forcibly produce unusual node data (simulated or 
mocked). Such testing reveals how the library responds when ring sizes 
cannot be satisfied or if distribution data is incomplete.




\section*{References}
\begin{thebibliography}{9}
\bibitem{shamir1979share} Shamir, Adi. How to Share a Secret. Communications of the ACM, 1979.
\bibitem{shoup2000practical} Shoup, Victor. Practical Threshold Signatures. Advances in Cryptology---EUROCRYPT 2000, 2000.
\bibitem{bellare2006multi} Bellare, Mihir and Neven, Gregory. Multi-Signatures in the Plain Public-Key Model and a General Forking Lemma. Proceedings of the 13th ACM conference on Computer and communications security, 2006.
\bibitem{li1988analysis} Li, X and Malek, Miroslaw. Analysis of Speedup and Communication/Computation Ratio in Multiprocessor Systems. Proceedings. Real-Time Systems Symposium, 1988.
\bibitem{zhang2002id} Zhang, Fangguo and Liu, Shengli and Kim, Kwangjo. ID-Based One Round Authenticated Tripartite Key Agreement Protocol with Pairings. Cryptology ePrint Archive, 2002.
\bibitem{bunz2018bulletproofs} B\"unz, Benedikt and Bootle, Jonathan and Boneh, Dan and Poelstra, Andrew and Wuille, Pieter and Maxwell, Greg. Bulletproofs: Short Proofs for Confidential Transactions and More. 2018 IEEE symposium on security and privacy (SP), 2018.
\bibitem{clsag} Goodell, Brandon and Noether, Sarang and Blue, Arthur. Concise Linkable Ring Signatures and Forgery Against Adversarial Keys. Cryptology ePrint Archive, 2019.
\bibitem{liu2004linkable} Liu, Joseph K and Wei, Victor K and Wong, Duncan S. Linkable Spontaneous Anonymous Group Signature for Ad Hoc Groups. Information Security and Privacy: 9th Australasian Conference, ACISP 2004, 2004.
\bibitem{goodell2018thring} Goodell, Brandon and Noether, Sarang. Thring Signatures and Their Applications to Spender-Ambiguous Digital Currencies. Cryptology ePrint Archive, 2018.
\bibitem{komlo2021frost} Komlo, Chelsea and Goldberg, Ian. FROST: Flexible Round-Optimized Schnorr Threshold Signatures. Selected Areas in Cryptography 2020, 2021.
\bibitem{SeraiRepo} Luke Parker. monero-oxide. GitHub repository, 2024.
\bibitem{bellare2022better} Bellare, Mihir and Crites, Elizabeth C and Komlo, Chelsea and Maller, Mary and Tessaro, Stefano and Zhu, Chenzhi. Better than Advertised Security for Non-interactive Threshold Signatures. Advances in Cryptology---CRYPTO 2022, 2022.
\end{thebibliography}

\end{document}
''';
