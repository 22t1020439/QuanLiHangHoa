import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import '../services/firestore_service.dart';
import '../models/product_model.dart';
import '../models/transaction_model.dart';

class AIAssistantScreen extends StatefulWidget {
  const AIAssistantScreen({super.key});

  @override
  State<AIAssistantScreen> createState() => _AIAssistantScreenState();
}

class _AIAssistantScreenState extends State<AIAssistantScreen> {
  final TextEditingController _controller = TextEditingController();
  final List<Map<String, String>> _messages = [
    {
      'role': 'assistant',
      'text':
          'Chào bạn! Tôi là trợ lý ảo Dã Viên. Tôi có thể giúp bạn xem thống kê hàng hóa, kiểm tra tồn kho hoặc báo cáo xuất nhập. Bạn muốn hỏi gì không?',
    },
  ];
  bool _isLoading = false;
  final FirestoreService _service = FirestoreService();

  void _addMessage(String role, String text) {
    setState(() {
      _messages.add({'role': role, 'text': text});
    });
  }

  Future<void> _processQuery(String query) async {
    _addMessage('user', query);
    setState(() => _isLoading = true);
    _controller.clear();

    String response = "";
    final q = query.toLowerCase();

    try {
      if (q.contains('xuất') && (q.contains('đà nẵng') || q.contains('đn'))) {
        response = await _handleStatsQuery(
          q,
          TransactionType.export,
          ProductType.dong,
        );
      } else if (q.contains('xuất') && q.contains('nội bộ')) {
        response = await _handleStatsQuery(
          q,
          TransactionType.export,
          ProductType.noiBo,
        );
      } else if (q.contains('nhập') &&
          (q.contains('đà nẵng') || q.contains('đn'))) {
        response = await _handleStatsQuery(
          q,
          TransactionType.import,
          ProductType.dong,
        );
      } else if (q.contains('nhập') && q.contains('nội bộ')) {
        response = await _handleStatsQuery(
          q,
          TransactionType.import,
          ProductType.noiBo,
        );
      } else if (q.contains('sắp hết') ||
          q.contains('cảnh báo') ||
          q.contains('tồn kho thấp')) {
        response = await _handleLowStockQuery();
      } else if (q.contains('tổng') ||
          q.contains('bao nhiêu') ||
          q.contains('tồn kho')) {
        response = await _handleTotalStockQuery(q);
      } else {
        response =
            "Xin lỗi, tôi chưa hiểu yêu cầu của bạn. Bạn có thể hỏi ví dụ: 'Lượng hàng xuất Đà Nẵng tháng 3/2026', 'Tổng số lượng hàng Đà Nẵng' hoặc 'Sản phẩm nào sắp hết hàng?'";
      }
    } catch (e) {
      response = "Có lỗi xảy ra khi truy vấn dữ liệu: $e";
    }

    _addMessage('assistant', response);
    setState(() => _isLoading = false);
  }

  Future<String> _handleStatsQuery(
    String q,
    TransactionType txType,
    ProductType pType,
  ) async {
    // Regex tìm tháng/năm
    final monthRegex = RegExp(r'tháng (\d{1,2})');
    final yearRegex = RegExp(r'năm (\d{4})|(\d{4})');

    int month = DateTime.now().month;
    int year = DateTime.now().year;

    final monthMatch = monthRegex.firstMatch(q);
    if (monthMatch != null) month = int.parse(monthMatch.group(1)!);

    final yearMatch = yearRegex.firstMatch(q);
    if (yearMatch != null) {
      String y = yearMatch.group(1) ?? yearMatch.group(2)!;
      year = int.parse(y);
    }

    final start = DateTime(year, month, 1);
    final end = DateTime(year, month + 1, 0, 23, 59, 59);

    final stats = await _service.getDetailedStats(
      start: start,
      end: end,
      txType: txType,
      productType: pType,
    );

    if (stats.isEmpty) {
      return "Không có dữ liệu ${txType == TransactionType.export ? "xuất" : "nhập"} hàng ${pType == ProductType.dong ? "Đà Nẵng" : "Nội bộ"} trong tháng $month/$year.";
    }

    double total = stats.values.reduce((a, b) => a + b);
    String res =
        "Thống kê ${txType == TransactionType.export ? "xuất" : "nhập"} hàng ${pType == ProductType.dong ? "Đà Nẵng" : "Nội bộ"} tháng $month/$year:\n";
    res += "- Tổng số lượng: $total\n";
    res += "- Chi tiết từng món:\n";
    stats.forEach((name, qty) {
      res += "  + $name: $qty\n";
    });

    return res;
  }

  Future<String> _handleLowStockQuery() async {
    // Giả sử ngưỡng thấp là 10 (có thể lấy từ Firestore nếu có)
    final snapshot = await _service.getProducts(ProductType.dong).first;
    final snapshot2 = await _service.getProducts(ProductType.noiBo).first;

    final lowStock = [
      ...snapshot,
      ...snapshot2,
    ].where((p) => p.stock <= 10).toList();

    if (lowStock.isEmpty)
      return "Hiện tại không có sản phẩm nào sắp hết hàng (tất cả đều > 10).";

    String res = "Danh sách sản phẩm sắp hết hàng (<= 10):\n";
    for (var p in lowStock) {
      res +=
          "- ${p.name}: ${p.stock} ${p.unit} (${p.type == ProductType.dong ? "Đà Nẵng" : "Nội bộ"})\n";
    }
    return res;
  }

  Future<String> _handleTotalStockQuery(String q) async {
    final stats = await _service.getDashboardStats().first;

    if (q.contains('đà nẵng') || q.contains('đn')) {
      return "Thống kê hàng Đà Nẵng:\n- Số loại sản phẩm: ${stats['countDong']}\n- Tổng số lượng tồn: ${stats['totalQtyDong']}";
    } else if (q.contains('nội bộ')) {
      return "Thống kê hàng Nội Bộ:\n- Số loại sản phẩm: ${stats['countNoiBo']}\n- Tổng số lượng tồn: ${stats['totalQtyNoiBo']}";
    }

    double grandTotal =
        (stats['totalQtyDong'] ?? 0.0) + (stats['totalQtyNoiBo'] ?? 0.0);
    return "Tổng quan hệ thống:\n- Hàng Đà Nẵng: ${stats['countDong']} loại (${stats['totalQtyDong']} SP)\n- Hàng Nội Bộ: ${stats['countNoiBo']} loại (${stats['totalQtyNoiBo']} SP)\n- Tổng tồn kho: $grandTotal sản phẩm.";
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Trợ lý AI Dã Viên'),
        centerTitle: true,
        backgroundColor: Colors.indigo,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(15),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isAssistant = msg['role'] == 'assistant';
                return Align(
                  alignment: isAssistant
                      ? Alignment.centerLeft
                      : Alignment.centerRight,
                  child: Container(
                    margin: const EdgeInsets.symmetric(vertical: 5),
                    padding: const EdgeInsets.all(12),
                    constraints: BoxConstraints(
                      maxWidth: MediaQuery.of(context).size.width * 0.75,
                    ),
                    decoration: BoxDecoration(
                      color: isAssistant ? Colors.grey[200] : Colors.indigo,
                      borderRadius: BorderRadius.circular(15).copyWith(
                        bottomLeft: isAssistant
                            ? const Radius.circular(0)
                            : const Radius.circular(15),
                        bottomRight: isAssistant
                            ? const Radius.circular(15)
                            : const Radius.circular(0),
                      ),
                    ),
                    child: Text(
                      msg['text']!,
                      style: TextStyle(
                        color: isAssistant ? Colors.black87 : Colors.white,
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          if (_isLoading)
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: SpinKitThreeBounce(color: Colors.indigo, size: 20),
            ),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(color: Colors.grey.withOpacity(0.2), blurRadius: 5),
              ],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _controller,
                    decoration: const InputDecoration(
                      hintText: 'Hỏi tôi về hàng hóa...',
                      border: InputBorder.none,
                    ),
                    onSubmitted: _processQuery,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: Colors.indigo),
                  onPressed: () => _processQuery(_controller.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
