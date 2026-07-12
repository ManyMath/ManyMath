const sampleDocument = r'''
\title{The Basel Problem}
\author{Leonhard Euler (retold in ManyMath)}
\date{1735}

\begin{document}
\maketitle

\section{The problem}

Find the exact sum of the reciprocals of the squares of the natural
numbers, that is, evaluate
\[
  \sum_{n=1}^{\infty} \frac{1}{n^2}
  = 1 + \frac{1}{4} + \frac{1}{9} + \frac{1}{16} + \cdots
\]

The series clearly converges --- compare it with the telescoping series
$\sum \frac{1}{n(n+1)} = 1$ --- but its exact value resisted the
\textit{Bernoullis} for decades.

\section{Euler's insight}

Euler considered the Taylor series of $\frac{\sin x}{x}$ and treated it as an
\emph{infinite polynomial} with roots at $x = \pm\pi, \pm 2\pi, \ldots$:

\begin{align}
  \frac{\sin x}{x} &= \prod_{n=1}^{\infty}
    \left(1 - \frac{x^2}{n^2\pi^2}\right) \\
  &= 1 - \frac{x^2}{6} + \frac{x^4}{120} - \cdots
\end{align}

Comparing the $x^2$ coefficients of both sides gives the celebrated result:

\begin{equation}
  \sum_{n=1}^{\infty} \frac{1}{n^2} = \frac{\pi^2}{6}
\end{equation}

\section{Why it matters}

\begin{itemize}
  \item It launched the study of $\zeta(s) = \sum n^{-s}$, the
        \textbf{Riemann zeta function}.
  \item The same technique yields $\zeta(4) = \frac{\pi^4}{90}$ and beyond.
  \item It connects analysis and number theory: $\zeta(2) = \frac{\pi^2}{6}$
        equals $\prod_p \frac{1}{1 - p^{-2}}$ over the primes.
\end{itemize}

% Comments never reach the output.
Edit this source and render the document when you are ready.
\end{document}
''';
