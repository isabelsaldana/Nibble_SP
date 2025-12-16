import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ReportTarget {
  /// 'user' | 'recipe' | 'comment' | 'reply'
  final String kind;

  /// The thing being reported (userId, recipeId, commentId, replyId)
  final String targetId;

  const ReportTarget({
    required this.kind,
    required this.targetId,
  });

  // ✅ Backward-compatible factories (accept old params so your pages compile)
  factory ReportTarget.user({
    required String userId,
  }) {
    return ReportTarget(kind: 'user', targetId: userId);
  }

  factory ReportTarget.recipe({
    required String recipeId,
    String? authorId, // (ignored, kept for compatibility)
  }) {
    return ReportTarget(kind: 'recipe', targetId: recipeId);
  }

  factory ReportTarget.comment({
    required String recipeId, // (ignored, kept for compatibility)
    required String commentId,
    String? authorId, // (ignored)
  }) {
    return ReportTarget(kind: 'comment', targetId: commentId);
  }

  factory ReportTarget.reply({
    required String recipeId, // (ignored)
    required String commentId, // (ignored)
    required String replyId,
    String? authorId, // (ignored)
  }) {
    return ReportTarget(kind: 'reply', targetId: replyId);
  }
}

class ReportService {
  /// Creates one report per reporter per target:
  /// /reports/{kind}/targets/{targetId}/reports/{reporterUid}
  static Future<void> submit({
    required ReportTarget target,
    required String reason,
    String? details,
  }) async {
    final me = FirebaseAuth.instance.currentUser;
    if (me == null) throw Exception('Not signed in');

    final cleanedReason = reason.trim();
    final cleanedDetails = (details ?? '').trim();

    final ref = FirebaseFirestore.instance
        .collection('reports')
        .doc(target.kind)
        .collection('targets')
        .doc(target.targetId)
        .collection('reports')
        .doc(me.uid); // ✅ unique reporter = unique count

    final data = <String, dynamic>{
      'reporterUid': me.uid,
      'kind': target.kind,
      'targetId': target.targetId,
      'reason': cleanedReason,
      'createdAt': FieldValue.serverTimestamp(),
    };

    if (cleanedDetails.isNotEmpty) {
      data['details'] = cleanedDetails;
    }

    await ref.set(data);
  }
}
