import 'sample_document.dart';

/// A built-in starting point for a local ManyMath document.
class DocumentTemplate {
  const DocumentTemplate({
    required this.name,
    required this.description,
    required this.source,
  });

  final String name;
  final String description;
  final String source;
}

const blankTemplate = DocumentTemplate(
  name: 'Blank',
  description: 'An empty document skeleton.',
  source: r'''
\title{Untitled}
\author{}
\date{}

\begin{document}
\maketitle

Start typing here.
\end{document}
''',
);

const articleTemplate = DocumentTemplate(
  name: 'Article',
  description: 'A short mathematical article using the Basel problem.',
  source: sampleDocument,
);

const problemSetTemplate = DocumentTemplate(
  name: 'Problem set',
  description: 'Numbered problems with space for worked solutions.',
  source: r'''
\title{Problem Set 1}
\author{Your Name}
\date{Due Friday}

\begin{document}
\maketitle

\section{Problems}

\begin{enumerate}
  \item Show that $\sqrt{2}$ is irrational.
  \item Evaluate $\int_0^1 x^2 \, dx$.
  \item For which $x$ does $\sum_{n=0}^{\infty} x^n$ converge?
\end{enumerate}

\section{Solutions}

\textbf{Problem 2.} By the power rule,

\begin{align}
  \int_0^1 x^2 \, dx &= \left[ \frac{x^3}{3} \right]_0^1 \\
  &= \frac{1}{3} - 0 = \frac{1}{3}
\end{align}

\textbf{Problem 3.} The geometric series converges exactly when $|x| < 1$:
\[
  \sum_{n=0}^{\infty} x^n = \frac{1}{1 - x}.
\]
\end{document}
''',
);

const lectureNotesTemplate = DocumentTemplate(
  name: 'Lecture notes',
  description: 'Sectioned notes with definitions and examples.',
  source: r'''
\title{Lecture 1: Limits}
\author{Course Notes}
\date{}

\begin{document}
\maketitle

\section{Definition}

We say $\lim_{x \to a} f(x) = L$ when $f(x)$ gets arbitrarily close to $L$
as $x$ approaches $a$. Formally:

\[
  \forall \varepsilon > 0 \; \exists \delta > 0 :
  0 < |x - a| < \delta \implies |f(x) - L| < \varepsilon
\]

\section{Key facts}

\begin{itemize}
  \item Limits are unique when they exist.
  \item Limits respect sums and products.
  \item The squeeze theorem compares a function with matching bounds.
\end{itemize}

\section{A classic example}

\begin{equation}
  \lim_{x \to 0} \frac{\sin x}{x} = 1
\end{equation}

This limit is the reason $\frac{d}{dx} \sin x = \cos x$.
\end{document}
''',
);

const documentTemplates = <DocumentTemplate>[
  blankTemplate,
  articleTemplate,
  problemSetTemplate,
  lectureNotesTemplate,
];

/// The template used only when no local document store exists yet.
const welcomeTemplate = articleTemplate;
