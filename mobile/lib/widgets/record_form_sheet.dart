export 'edit_form_sheet.dart';

import 'package:flutter/material.dart';

import '../models/models.dart';
import '../services/api_service.dart';
import 'edit_form_sheet.dart';

Future<bool> showRecordFormSheet({
  required BuildContext context,
  required ApiService api,
  required List<Product> products,
  AnalysisRecord? record,
}) {
  return showEditFormSheet(
    context: context,
    api: api,
    products: products,
    record: record,
  );
}
