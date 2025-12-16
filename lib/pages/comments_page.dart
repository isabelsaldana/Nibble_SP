import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';


// ✅ new
import '../moderation/report_ui.dart';
import '../moderation/report_service.dart';


class CommentsPage extends StatefulWidget {
 final String recipeId;
 final String? recipeTitle;


 const CommentsPage({
   super.key,
   required this.recipeId,
   this.recipeTitle,
 });


 @override
 State<CommentsPage> createState() => _CommentsPageState();
}


class _CommentsPageState extends State<CommentsPage> {
 final _controller = TextEditingController();
 final _focusNode = FocusNode();
 bool _sending = false;


 // reply mode
 String? _replyToCommentId;
 String? _replyToUsername;


 Future<Map<String, dynamic>> _loadMeProfile(String uid) async {
   final snap = await FirebaseFirestore.instance.collection('users').doc(uid).get();
   final u = snap.data() ?? <String, dynamic>{};


   final displayName = (u['displayName'] ?? '').toString().trim();
   final username = (u['username'] ?? '').toString().trim();


   String? photo = (u['photo'] ?? u['photoUrl'] ?? u['photoURL'] ?? u['avatar'])
       ?.toString()
       .trim();
   if (photo != null && photo.isEmpty) photo = null;


   return {
     'displayName': displayName.isNotEmpty ? displayName : 'Nibble user',
     'username': username,
     'photo': photo,
   };
 }


 CollectionReference<Map<String, dynamic>> _commentsCol() {
   return FirebaseFirestore.instance
       .collection('recipes')
       .doc(widget.recipeId)
       .collection('comments');
 }


 CollectionReference<Map<String, dynamic>> _repliesCol(String commentId) {
   return _commentsCol().doc(commentId).collection('replies');
 }


 DocumentReference<Map<String, dynamic>> _reactionDoc(String commentId, String uid) {
   return _commentsCol().doc(commentId).collection('reactions').doc(uid);
 }


 void _startReply({required String commentId, required String username}) {
   setState(() {
     _replyToCommentId = commentId;
     _replyToUsername = username.isNotEmpty ? username : null;
   });
   _focusNode.requestFocus();
 }


 void _cancelReply() {
   setState(() {
     _replyToCommentId = null;
     _replyToUsername = null;
   });
 }


 Future<void> _send() async {
   final me = FirebaseAuth.instance.currentUser;
   if (me == null) return;


   final text = _controller.text.trim();
   if (text.isEmpty) return;


   setState(() => _sending = true);


   try {
     final profile = await _loadMeProfile(me.uid);


     final payload = {
       'authorId': me.uid,
       'authorName': profile['displayName'],
       'authorUsername': profile['username'],
       'authorPhoto': profile['photo'],
       'text': text,
       'createdAt': FieldValue.serverTimestamp(),
     };


     if (_replyToCommentId != null) {
       await _repliesCol(_replyToCommentId!).add(payload);
     } else {
       await _commentsCol().add(payload);
     }


     _controller.clear();
     _cancelReply();
   } catch (e) {
     if (mounted) {
       ScaffoldMessenger.of(context).showSnackBar(
         SnackBar(content: Text('Failed to comment: $e')),
       );
     }
   } finally {
     if (mounted) setState(() => _sending = false);
   }
 }


 Future<void> _toggleReaction({
   required String commentId,
   required String type, // 'like' | 'dislike'
 }) async {
   final me = FirebaseAuth.instance.currentUser;
   if (me == null) return;


   final ref = _reactionDoc(commentId, me.uid);


   await FirebaseFirestore.instance.runTransaction((tx) async {
     final snap = await tx.get(ref);


     if (!snap.exists) {
       tx.set(ref, {
         'type': type,
         'createdAt': FieldValue.serverTimestamp(),
       });
       return;
     }


     final current = (snap.data()?['type'] ?? '').toString();


     if (current == type) {
       tx.delete(ref);
       return;
     }


     tx.set(
       ref,
       {'type': type, 'createdAt': FieldValue.serverTimestamp()},
       SetOptions(merge: true),
     );
   });
 }


 Future<bool> _confirmDeleteDialog({required String label}) async {
   final ok = await showDialog<bool>(
         context: context,
         builder: (ctx) => AlertDialog(
           title: Text('Delete $label?'),
           content: const Text('This can’t be undone.'),
           actions: [
             TextButton(
               onPressed: () => Navigator.of(ctx).pop(false),
               child: const Text('Cancel'),
             ),
             FilledButton(
               onPressed: () => Navigator.of(ctx).pop(true),
               child: const Text('Delete'),
             ),
           ],
         ),
       ) ??
       false;
   return ok;
 }


 @override
 void dispose() {
   _controller.dispose();
   _focusNode.dispose();
   super.dispose();
 }


 String _timeAgo(Timestamp? ts) {
   if (ts == null) return '';
   final dt = ts.toDate();
   final diff = DateTime.now().difference(dt);


   if (diff.inMinutes < 1) return 'now';
   if (diff.inMinutes < 60) return '${diff.inMinutes}m';
   if (diff.inHours < 24) return '${diff.inHours}h';
   return '${diff.inDays}d';
 }


 @override
 Widget build(BuildContext context) {
   final me = FirebaseAuth.instance.currentUser;


   return Scaffold(
     appBar: AppBar(
       title: Text(
         widget.recipeTitle?.trim().isNotEmpty == true
             ? 'Comments • ${widget.recipeTitle}'
             : 'Comments',
       ),
     ),
     body: Column(
       children: [
         if (_replyToCommentId != null)
           Container(
             width: double.infinity,
             padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
             color: Colors.brown.shade50,
             child: Row(
               children: [
                 Expanded(
                   child: Text(
                     _replyToUsername != null
                         ? 'Replying to @$_replyToUsername'
                         : 'Replying…',
                     style: TextStyle(
                       color: Colors.brown.shade700,
                       fontWeight: FontWeight.w600,
                     ),
                   ),
                 ),
                 IconButton(
                   onPressed: _cancelReply,
                   icon: const Icon(Icons.close),
                 )
               ],
             ),
           ),


         Expanded(
           child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
             stream: _commentsCol().orderBy('createdAt', descending: true).snapshots(),
             builder: (context, snap) {
               if (snap.hasError) {
                 return Padding(
                   padding: const EdgeInsets.all(24),
                   child: Text('Error: ${snap.error}'),
                 );
               }
               if (!snap.hasData) {
                 return const Center(child: CircularProgressIndicator());
               }


               final docs = snap.data!.docs;
               if (docs.isEmpty) {
                 return const Center(child: Text('No comments yet. Be the first!'));
               }


               return ListView.separated(
                 padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                 itemCount: docs.length,
                 separatorBuilder: (_, __) => const SizedBox(height: 12),
                 itemBuilder: (context, i) {
                   final doc = docs[i];
                   final d = doc.data();


                   final authorId = (d['authorId'] ?? '').toString();
                   final authorName = (d['authorName'] ?? 'User').toString();
                   final authorUsername = (d['authorUsername'] ?? '').toString();
                   final authorPhoto = (d['authorPhoto'] ?? '').toString().trim();
                   final text = (d['text'] ?? '').toString();
                   final createdAt = d['createdAt'] as Timestamp?;


                   final isMine = me != null && me.uid == authorId;


                   return _CommentTile(
                     recipeId: widget.recipeId,
                     commentId: doc.id,
                     authorId: authorId,
                     authorName: authorName,
                     authorUsername: authorUsername,
                     authorPhoto: authorPhoto,
                     text: text,
                     timeAgo: _timeAgo(createdAt),
                     isMine: isMine,
                     onReply: () => _startReply(
                       commentId: doc.id,
                       username: authorUsername.isNotEmpty ? authorUsername : authorName,
                     ),
                     onLike: () => _toggleReaction(commentId: doc.id, type: 'like'),
                     onDislike: () => _toggleReaction(commentId: doc.id, type: 'dislike'),
                     onDelete: () async {
                       final ok = await _confirmDeleteDialog(label: 'comment');
                       if (!ok) return;
                       await _commentsCol().doc(doc.id).delete();
                     },
                     onReport: () async {
                       await ReportUI.openReportSheet(
                         context,
                         title: 'Report comment',
                         target: ReportTarget.comment(
                           recipeId: widget.recipeId,
                           commentId: doc.id,
                           authorId: authorId,
                         ),
                       );
                     },
                   );
                 },
               );
             },
           ),
         ),


         SafeArea(
           top: false,
           child: Padding(
             padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
             child: Row(
               children: [
                 Expanded(
                   child: TextField(
                     focusNode: _focusNode,
                     controller: _controller,
                     minLines: 1,
                     maxLines: 4,
                     textInputAction: TextInputAction.send,
                     onSubmitted: (_) => _sending ? null : _send(),
                     decoration: InputDecoration(
                       hintText: _replyToUsername != null
                           ? 'Reply to @$_replyToUsername…'
                           : 'Add a comment…',
                       filled: true,
                       fillColor: Colors.brown.shade50,
                       border: OutlineInputBorder(
                         borderRadius: BorderRadius.circular(14),
                         borderSide: BorderSide.none,
                       ),
                       contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                     ),
                   ),
                 ),
                 const SizedBox(width: 10),
                 IconButton(
                   onPressed: _sending ? null : _send,
                   icon: _sending
                       ? const SizedBox(
                           width: 18,
                           height: 18,
                           child: CircularProgressIndicator(strokeWidth: 2),
                         )
                       : const Icon(Icons.send),
                 ),
               ],
             ),
           ),
         ),
       ],
     ),
   );
 }
}


class _CommentTile extends StatefulWidget {
 final String recipeId;
 final String commentId;


 final String authorId;
 final String authorName;
 final String authorUsername;
 final String authorPhoto;


 final String text;
 final String timeAgo;
 final bool isMine;


 final VoidCallback onReply;
 final VoidCallback onLike;
 final VoidCallback onDislike;


 final Future<void> Function() onDelete;
 final Future<void> Function() onReport;


 const _CommentTile({
   required this.recipeId,
   required this.commentId,
   required this.authorId,
   required this.authorName,
   required this.authorUsername,
   required this.authorPhoto,
   required this.text,
   required this.timeAgo,
   required this.isMine,
   required this.onReply,
   required this.onLike,
   required this.onDislike,
   required this.onDelete,
   required this.onReport,
 });


 @override
 State<_CommentTile> createState() => _CommentTileState();
}


class _CommentTileState extends State<_CommentTile> {
 bool _showReplies = false;


 CollectionReference<Map<String, dynamic>> _commentsCol() {
   return FirebaseFirestore.instance
       .collection('recipes')
       .doc(widget.recipeId)
       .collection('comments');
 }


 CollectionReference<Map<String, dynamic>> _repliesCol() {
   return _commentsCol().doc(widget.commentId).collection('replies');
 }


 CollectionReference<Map<String, dynamic>> _reactionsCol() {
   return _commentsCol().doc(widget.commentId).collection('reactions');
 }


 Future<void> _openMore() async {
   await showModalBottomSheet(
     context: context,
     showDragHandle: true,
     builder: (ctx) => SafeArea(
       child: Column(
         mainAxisSize: MainAxisSize.min,
         children: [
           if (widget.isMine)
             ListTile(
               leading: const Icon(Icons.delete_outline),
               title: const Text('Delete comment'),
               onTap: () async {
                 Navigator.pop(ctx);
                 await widget.onDelete();
               },
             )
           else
             ListTile(
               leading: const Icon(Icons.flag_outlined),
               title: const Text('Report comment'),
               onTap: () async {
                 Navigator.pop(ctx);
                 await widget.onReport();
               },
             ),
           const SizedBox(height: 8),
         ],
       ),
     ),
   );
 }


 @override
 Widget build(BuildContext context) {
   final me = FirebaseAuth.instance.currentUser;
   final nameLine = widget.authorUsername.isNotEmpty ? '@${widget.authorUsername}' : widget.authorName;


   return Row(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
       CircleAvatar(
         radius: 18,
         backgroundImage: widget.authorPhoto.startsWith('http')
             ? NetworkImage(widget.authorPhoto)
             : null,
         child: widget.authorPhoto.isEmpty
             ? Text(widget.authorName.isNotEmpty ? widget.authorName[0].toUpperCase() : 'U')
             : null,
       ),
       const SizedBox(width: 10),


       Expanded(
         child: Column(
           crossAxisAlignment: CrossAxisAlignment.start,
           children: [
             Container(
               padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
               decoration: BoxDecoration(
                 color: Colors.brown.shade50,
                 borderRadius: BorderRadius.circular(14),
               ),
               child: Column(
                 crossAxisAlignment: CrossAxisAlignment.start,
                 children: [
                   Row(
                     children: [
                       Expanded(
                         child: Text(
                           nameLine,
                           style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 13),
                         ),
                       ),
                       Text(
                         widget.timeAgo,
                         style: const TextStyle(fontSize: 12, color: Colors.black54),
                       ),
                       const SizedBox(width: 4),
                       IconButton(
                         visualDensity: VisualDensity.compact,
                         padding: EdgeInsets.zero,
                         constraints: const BoxConstraints(),
                         onPressed: _openMore,
                         icon: const Icon(Icons.more_horiz, size: 18),
                       ),
                     ],
                   ),
                   const SizedBox(height: 6),
                   Text(widget.text),
                 ],
               ),
             ),


             const SizedBox(height: 6),


             Row(
               children: [
                 TextButton(
                   onPressed: widget.onReply,
                   child: const Text('Reply'),
                 ),
                 const SizedBox(width: 6),


                 StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                   stream: _reactionsCol().where('type', isEqualTo: 'like').snapshots(),
                   builder: (context, snap) {
                     final likeCount = snap.data?.docs.length ?? 0;
                     return InkWell(
                       onTap: widget.onLike,
                       child: Row(
                         children: [
                           const Icon(Icons.favorite_border, size: 18),
                           const SizedBox(width: 4),
                           Text('$likeCount'),
                         ],
                       ),
                     );
                   },
                 ),


                 const SizedBox(width: 14),


                 StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                   stream: _reactionsCol().where('type', isEqualTo: 'dislike').snapshots(),
                   builder: (context, snap) {
                     final dislikeCount = snap.data?.docs.length ?? 0;
                     return InkWell(
                       onTap: widget.onDislike,
                       child: Row(
                         children: [
                           const Icon(Icons.thumb_down_alt_outlined, size: 18),
                           const SizedBox(width: 4),
                           Text('$dislikeCount'),
                         ],
                       ),
                     );
                   },
                 ),
               ],
             ),


             StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
               stream: _repliesCol().orderBy('createdAt', descending: false).snapshots(),
               builder: (context, snap) {
                 final replies = snap.data?.docs ?? [];
                 if (replies.isEmpty) return const SizedBox();


                 return Column(
                   crossAxisAlignment: CrossAxisAlignment.start,
                   children: [
                     InkWell(
                       onTap: () => setState(() => _showReplies = !_showReplies),
                       child: Padding(
                         padding: const EdgeInsets.symmetric(vertical: 6),
                         child: Text(
                           _showReplies
                               ? 'Hide replies'
                               : 'View ${replies.length} repl${replies.length == 1 ? 'y' : 'ies'}',
                           style: TextStyle(
                             color: Colors.brown.shade700,
                             fontWeight: FontWeight.w700,
                           ),
                         ),
                       ),
                     ),
                     if (_showReplies)
                       for (final r in replies.take(20))
                         _ReplyTile(
                           recipeId: widget.recipeId,
                           commentId: widget.commentId,
                           replyId: r.id,
                           data: r.data(),
                         ),
                   ],
                 );
               },
             ),
           ],
         ),
       ),
     ],
   );
 }
}


class _ReplyTile extends StatelessWidget {
 final String recipeId;
 final String commentId;
 final String replyId;
 final Map<String, dynamic> data;


 const _ReplyTile({
   required this.recipeId,
   required this.commentId,
   required this.replyId,
   required this.data,
 });


 String _timeAgo(Timestamp? ts) {
   if (ts == null) return '';
   final diff = DateTime.now().difference(ts.toDate());
   if (diff.inMinutes < 1) return 'now';
   if (diff.inMinutes < 60) return '${diff.inMinutes}m';
   if (diff.inHours < 24) return '${diff.inHours}h';
   return '${diff.inDays}d';
 }


 @override
 Widget build(BuildContext context) {
   final me = FirebaseAuth.instance.currentUser;


   final authorId = (data['authorId'] ?? '').toString();
   final authorName = (data['authorName'] ?? 'User').toString();
   final authorUsername = (data['authorUsername'] ?? '').toString();
   final authorPhoto = (data['authorPhoto'] ?? '').toString().trim();
   final text = (data['text'] ?? '').toString();
   final createdAt = data['createdAt'] as Timestamp?;


   final isMine = me != null && me.uid == authorId;


   final ref = FirebaseFirestore.instance
       .collection('recipes')
       .doc(recipeId)
       .collection('comments')
       .doc(commentId)
       .collection('replies')
       .doc(replyId);


   Future<void> confirmDelete() async {
     final ok = await showDialog<bool>(
           context: context,
           builder: (ctx) => AlertDialog(
             title: const Text('Delete reply?'),
             content: const Text('This can’t be undone.'),
             actions: [
               TextButton(
                 onPressed: () => Navigator.of(ctx).pop(false),
                 child: const Text('Cancel'),
               ),
               FilledButton(
                 onPressed: () => Navigator.of(ctx).pop(true),
                 child: const Text('Delete'),
               ),
             ],
           ),
         ) ??
         false;


     if (!ok) return;
     await ref.delete();
   }


   Future<void> openMore() async {
     await showModalBottomSheet(
       context: context,
       showDragHandle: true,
       builder: (ctx) => SafeArea(
         child: Column(
           mainAxisSize: MainAxisSize.min,
           children: [
             if (isMine)
               ListTile(
                 leading: const Icon(Icons.delete_outline),
                 title: const Text('Delete reply'),
                 onTap: () async {
                   Navigator.pop(ctx);
                   await confirmDelete();
                 },
               )
             else
               ListTile(
                 leading: const Icon(Icons.flag_outlined),
                 title: const Text('Report reply'),
                 onTap: () async {
                   Navigator.pop(ctx);
                   await ReportUI.openReportSheet(
                     context,
                     title: 'Report reply',
                     target: ReportTarget.reply(
                       recipeId: recipeId,
                       commentId: commentId,
                       replyId: replyId,
                       authorId: authorId,
                     ),
                   );
                 },
               ),
             const SizedBox(height: 8),
           ],
         ),
       ),
     );
   }


   return Padding(
     padding: const EdgeInsets.only(left: 36, top: 6),
     child: Row(
       crossAxisAlignment: CrossAxisAlignment.start,
       children: [
         CircleAvatar(
           radius: 14,
           backgroundImage: authorPhoto.startsWith('http') ? NetworkImage(authorPhoto) : null,
           child: authorPhoto.isEmpty ? Text(authorName.isNotEmpty ? authorName[0].toUpperCase() : 'U') : null,
         ),
         const SizedBox(width: 8),
         Expanded(
           child: Container(
             padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
             decoration: BoxDecoration(
               color: Colors.brown.shade50,
               borderRadius: BorderRadius.circular(12),
             ),
             child: Row(
               crossAxisAlignment: CrossAxisAlignment.start,
               children: [
                 Expanded(
                   child: RichText(
                     text: TextSpan(
                       style: const TextStyle(color: Colors.black),
                       children: [
                         TextSpan(
                           text: authorUsername.isNotEmpty ? '@$authorUsername ' : '$authorName ',
                           style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                         ),
                         TextSpan(text: text),
                       ],
                     ),
                   ),
                 ),
                 const SizedBox(width: 8),
                 Text(_timeAgo(createdAt), style: const TextStyle(fontSize: 11, color: Colors.black54)),
                 const SizedBox(width: 6),
                 IconButton(
                   padding: EdgeInsets.zero,
                   constraints: const BoxConstraints(),
                   icon: const Icon(Icons.more_horiz, size: 16),
                   onPressed: openMore,
                 ),
               ],
             ),
           ),
         ),
       ],
     ),
   );
 }
}
