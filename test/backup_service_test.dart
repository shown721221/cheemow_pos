import 'package:flutter_test/flutter_test.dart';
import 'package:cheemeow_pos/services/backup_service.dart';
import 'package:cheemeow_pos/services/local_database_service.dart';
import 'package:cheemeow_pos/services/receipt_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('BackupService builds json with keys', () async {
    SharedPreferences.setMockInitialValues({});
    await LocalDatabaseService.instance.initialize();
    await LocalDatabaseService.instance.ensureSpecialProducts();
    await ReceiptService.instance.initialize();

    final json = await BackupService.instance.buildBackupJson();
    expect(json.contains('backupVersion'), true);
    expect(json.contains('productsCount'), true);
    expect(json.contains('receiptsCount'), true);
    expect(json.contains('products'), true);
    expect(json.contains('receipts'), true);
  });
}
