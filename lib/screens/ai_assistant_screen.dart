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
      // 1. Phân loại sản phẩm (Đà Nẵng hay Nội Bộ)
      ProductType? pType;
      if (q.contains('đà nẵng') || q.contains('đn')) {
        pType = ProductType.dong;
      } else if (q.contains('nội bộ') || q.contains('nb')) {
        pType = ProductType.noiBo;
      }

      // 2. Xác định hành động (Xuất, Nhập, Tồn kho)
      if (q.contains('xuất') || q.contains('bán')) {
        response = await _handleTransactionQuery(
          q,
          TransactionType.export,
          pType,
        );
      } else if (q.contains('nhập') || q.contains('mua')) {
        response = await _handleTransactionQuery(
          q,
          TransactionType.import,
          pType,
        );
      } else if (q.contains('sắp hết') ||
          q.contains('cảnh báo') ||
          q.contains('tồn kho thấp') ||
          q.contains('hết hàng')) {
        response = await _handleLowStockQuery();
      } else if (q.contains('số loại') ||
          q.contains('có bao nhiêu loại') ||
          q.contains('mặt hàng')) {
        response = await _handleTypeCountQuery(pType);
      } else if (q.contains('tổng') ||
          q.contains('bao nhiêu') ||
          q.contains('tồn kho')) {
        response = await _handleStockSumQuery(pType);
      } else {
        response =
            "Xin lỗi, tôi chưa hiểu rõ ý bạn. Bạn có thể thử hỏi:\n- 'Số loại sản phẩm của hàng Đà Nẵng'\n- 'Tổng số lượng hàng nội bộ'\n- 'Hàng xuất Đà Nẵng ngày 17/4/2026'\n- 'Sản phẩm nào sắp hết hàng?'";
      }
    } catch (e) {
      response = "Có lỗi xảy ra khi xử lý câu hỏi: $e";
    }

    _addMessage('assistant', response);
    setState(() => _isLoading = false);
  }

  Future<String> _handleTransactionQuery(
    String q,
    TransactionType txType,
    ProductType? pType,
  ) async {
    if (pType == null)
      return "Bạn muốn xem hàng xuất/nhập của 'Đà Nẵng' hay 'Nội bộ' ạ?";

    // Regex phân tích thời gian
    final dayRegex = RegExp(r'ngày (\d{1,2})');
    final monthRegex = RegExp(r'tháng (\d{1,2})');
    final yearRegex = RegExp(r'năm (\d{4})|(\d{4})');

    DateTime now = DateTime.now();
    int? day;
    int month = now.month;
    int year = now.year;

    final dayMatch = dayRegex.firstMatch(q);
    if (dayMatch != null) day = int.parse(dayMatch.group(1)!);

    final monthMatch = monthRegex.firstMatch(q);
    if (monthMatch != null) month = int.parse(monthMatch.group(1)!);

    final yearMatch = yearRegex.firstMatch(q);
    if (yearMatch != null) {
      String y = yearMatch.group(1) ?? yearMatch.group(2)!;
      year = int.parse(y);
    }

    DateTime start, end;
    String timeStr;

    if (day != null) {
      start = DateTime(year, month, day, 0, 0, 0);
      end = DateTime(year, month, day, 23, 59, 59);
      timeStr = "ngày $day/$month/$year";
    } else {
      start = DateTime(year, month, 1);
      end = DateTime(year, month + 1, 0, 23, 59, 59);
      timeStr = "tháng $month/$year";
    }

    final stats = await _service.getDetailedStats(
      start: start,
      end: end,
      txType: txType,
      productType: pType,
    );

    String typeName = pType == ProductType.dong ? "Đà Nẵng" : "Nội bộ";
    String actionName = txType == TransactionType.export ? "xuất" : "nhập";

    if (stats.isEmpty) {
      return "Không có dữ liệu $actionName hàng $typeName trong $timeStr.";
    }

    double total = stats.values.reduce((a, b) => a + b);
    String res = "Thống kê $actionName hàng $typeName ($timeStr):\n";
    res += "- Tổng số lượng: $total\n";
    res += "- Chi tiết:\n";
    stats.forEach((name, qty) {
      res += "  + $name: $qty\n";
    });

    return res;
  }

  Future<String> _handleTypeCountQuery(ProductType? pType) async {
    final stats = await _service.getDashboardStats().first;
    if (pType == ProductType.dong) {
      return "Hàng Đà Nẵng hiện có ${stats['countDong']} loại sản phẩm khác nhau.";
    } else if (pType == ProductType.noiBo) {
      return "Hàng Nội Bộ hiện có ${stats['countNoiBo']} loại sản phẩm khác nhau.";
    }
    return "Hệ thống đang quản lý:\n- ${stats['countDong']} loại hàng Đà Nẵng\n- ${stats['countNoiBo']} loại hàng Nội Bộ.";
  }

  Future<String> _handleStockSumQuery(ProductType? pType) async {
    final stats = await _service.getDashboardStats().first;
    if (pType == ProductType.dong) {
      return "Tổng số lượng tồn kho của hàng Đà Nẵng là: ${stats['totalQtyDong']} sản phẩm.";
    } else if (pType == ProductType.noiBo) {
      return "Tổng số lượng tồn kho của hàng Nội Bộ là: ${stats['totalQtyNoiBo']} sản phẩm.";
    }
    double total =
        (stats['totalQtyDong'] ?? 0.0) + (stats['totalQtyNoiBo'] ?? 0.0);
    return "Tổng tồn kho toàn hệ thống là $total sản phẩm (${stats['totalQtyDong']} Đà Nẵng, ${stats['totalQtyNoiBo']} Nội bộ).";
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
