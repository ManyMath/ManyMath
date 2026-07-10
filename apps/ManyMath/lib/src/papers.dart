import 'papers/carrot_core_audit.dart';
import 'papers/fcmpp_implementation_audit.dart';
import 'papers/frost_clsag_rosetta_stone.dart';
import 'papers/frostlass_code_audit.dart';
import 'papers/frostlass_thresholdization.dart';
import 'papers/rage_audit.dart';
import 'papers/rage_guide.dart';
import 'papers/tclsag_implementation_review.dart';

/// A real-world LaTeX paper bundled with ManyMath, used to seed a fresh
/// document store so the editor and the RaTeX engine are exercised against
/// complex, hand-written formatting rather than only the toy templates in
/// `templates.dart`.
class PaperDocument {
  const PaperDocument({required this.name, required this.source});

  final String name;
  final String source;
}

/// The papers in `papers/` at the repository root, each reduced to its
/// root `.tex` file (none of them `\input` or `\include` another file).
const papers = <PaperDocument>[
  PaperDocument(
    name:
        'FROSTLASS: Flexible Ring-Oriented Schnorr-like Thresholdized '
        'Linkably Anonymous Signature Scheme',
    source: frostlassThresholdizationSource,
  ),
  PaperDocument(
    name: 'CARROT carrot_core Implementation Audit',
    source: carrotCoreAuditSource,
  ),
  PaperDocument(
    name: 'FCMP++ Crosswalk: Audit Locator Key',
    source: fcmppImplementationAuditSource,
  ),
  PaperDocument(
    name: 'Serai Monero Networks Audit',
    source: frostlassCodeAuditSource,
  ),
  PaperDocument(
    name: 'A Cryptographic and Implementation Review of Rage',
    source: rageAuditSource,
  ),
  PaperDocument(name: 'Rage Guide', source: rageGuideSource),
  PaperDocument(
    name: 'T-CLSAG Implementation Security Audit',
    source: tclsagImplementationReviewSource,
  ),
  PaperDocument(
    name: 'FROST × CLSAG Rosetta Stone',
    source: frostClsagRosettaStoneSource,
  ),
];
