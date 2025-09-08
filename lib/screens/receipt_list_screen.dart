import 'package:flutter/material.dart';
import '../services/receipt_service.dart';
import '../models/receipt.dart';

class ReceiptListScreen extends StatefulWidget {
  const ReceiptListScreen({super.key});

  @override
  State<ReceiptListScreen> createState() => _ReceiptListScreenState();
}

class _ReceiptListScreenState extends State<ReceiptListScreen> {
  late Future<List<Receipt>> _future;

  @override
  void initState() {
    super.initState();
    _future = ReceiptService.instance.getReceipts();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('收據清單'),
      ),
      body: FutureBuilder<List<Receipt>>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          final receipts = snapshot.data ?? [];
          if (receipts.isEmpty) {
            return const Center(child: Text('尚無收據'));
          }
          return ListView.separated(
            itemCount: receipts.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final r = receipts[index];
              return ListTile(
                title: Text(r.id),
                subtitle: Text('${r.formattedDateTime} ・ ${r.paymentMethod}'),
                trailing: Text('NT\$${r.totalAmount}'),
                onTap: () async {
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ReceiptDetailScreen(receipt: r),
                    ),
                  );
                  setState(() => _future = ReceiptService.instance.getReceipts());
                },
              );
            },
          );
        },
      ),
    );
  }
}

class ReceiptDetailScreen extends StatelessWidget {
  final Receipt receipt;
  const ReceiptDetailScreen({super.key, required this.receipt});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('收據 ${receipt.id}')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('時間：${receipt.formattedDateTime}'),
            const SizedBox(height: 4),
            Text('付款方式：${receipt.paymentMethod}'),
            const SizedBox(height: 8),
            const Text('商品明細：', style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.separated(
                itemCount: receipt.items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, index) {
                  final item = receipt.items[index];
                  final name = item.product.name;
                  final price = item.product.price;
                  final qty = item.quantity;
                  return ListTile(
                    dense: true,
                    title: Text(name),
                    subtitle: Text('單價 NT\$$price × $qty'),
                    trailing: Text('NT\$${item.subtotal}'),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: Text('總金額：NT\$${receipt.totalAmount}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}
