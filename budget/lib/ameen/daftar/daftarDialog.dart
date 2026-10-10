import 'package:budget/colors.dart';
import 'package:budget/widgets/textWidgets.dart';
import 'package:flutter/material.dart';

// Daftar is desktop-only, so its editors open as centred dialogs rather than
// bottom sheets. [builder] gets the dialog's own context: pop that one
// (Navigator.of(dialogContext).pop(result)) to close it.
Future<T?> showDaftarDialog<T>(
  BuildContext context, {
  required String title,
  required Widget Function(BuildContext dialogContext) builder,
  double maxWidth = 560,
}) {
  return showDialog<T>(
    context: context,
    builder: (dialogContext) {
      Size screen = MediaQuery.sizeOf(dialogContext);
      return Dialog(
        backgroundColor: getColor(dialogContext, "lightDarkAccent"),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: maxWidth,
            maxHeight: screen.height * 0.85,
          ),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(22, 18, 22, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: TextFont(
                        text: title,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(dialogContext).pop(),
                    ),
                  ],
                ),
                SizedBox(height: 10),
                Flexible(
                  child: SingleChildScrollView(child: builder(dialogContext)),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}
