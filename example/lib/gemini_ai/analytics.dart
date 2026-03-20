import 'dart:convert';
import 'dart:io';

import 'package:edge_detection_example/gemini_ai/data.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:google_generative_ai/google_generative_ai.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';

class PregnancyTestScreen extends StatefulWidget {
  @override
  _PregnancyTestScreenState createState() => _PregnancyTestScreenState();
}

class _PregnancyTestScreenState extends State<PregnancyTestScreen> {
  File? _image;
  String _resultText = "Chưa có kết quả";
  bool _isLoading = false;

  // ⚠️ THAY THẾ BẰNG API KEY CỦA BẠN
  // final String apiKey = dotenv.env['GEMINI_API_KEY']!;

  Future<void> _analyzeImage() async {
    if (_image == null) return;

    setState(() {
      _isLoading = true;
      _resultText = "Đang phân tích...";
    });
    print(dotenv.env['GEMINI_API_KEY']);
    try {
      // 1. Khởi tạo model Gemini 2.5 Flash (Nhanh và rẻ hơn Pro)
      final model = GenerativeModel(
        // model: 'gemini-3-flash-preview',
        model: 'gemini-2.5-flash',
        apiKey: dotenv.env['GEMINI_API_KEY']!,
        generationConfig: GenerationConfig(
          responseMimeType: "application/json", // Yêu cầu trả về JSON
        ),
      );

      // 2. Chuẩn bị ảnh
      final imageBytes = await _image!.readAsBytes();
      final content = [
        Content.multi([
          TextPart("""
Bạn là một chuyên gia về xét nghiệm sắc ký miễn dịch (Lateral Flow Assays), đặc biệt là phân tích que thử rụng trứng (LH).
Hãy thực hiện quy trình phân tích nghiêm ngặt qua 2 GIAI ĐOẠN dưới đây:

**GIAI ĐOẠN 1: KIỂM TRA CHẤT LƯỢNG HÌNH ẢNH (BẮT BUỘC)**
Trước khi đọc vạch, hãy kiểm tra các lỗi sau. Nếu gặp bất kỳ lỗi nào, hãy DỪNG LẠI và trả về kết quả "UNKNOWN" ngay lập tức kèm lời khuyên tương ứng.
1. **Không phải que thử**: Hình ảnh là vật thể khác, nền trống, hoặc que thử bị cắt cụt không nhìn thấy vùng hiển thị.
   -> Advice: "Không tìm thấy que thử hợp lệ. Vui lòng chụp trọn vẹn que thử."
2. **Ảnh quá mờ (Blurry)**: Không thể nhìn rõ đường nét sắc cạnh của que thử hoặc các ký tự trên que.
   -> Advice: "Ảnh quá mờ. Vui lòng giữ chắc tay và lấy nét lại."
3. **Ánh sáng kém**: Ảnh quá tối (không thấy rõ nền trắng của que) hoặc bị bóng lóa (glare) che mất vùng đọc kết quả.
   -> Advice: "Ánh sáng không tốt (quá tối hoặc bị lóa). Hãy chụp nơi đủ sáng."
4. **Sai chiều/Xoay ngang (Orientation Error)**: 
   - Que thử đang nằm theo chiều NGANG.
   - QUAN TRỌNG: Nếu vạch T và vạch C nằm CẠNH NHAU (Side-by-side / Left-Right) thay vì CHỒNG LÊN NHAU (Top-Bottom), hãy coi là LỖI.
   - AI chỉ chấp nhận hình ảnh que thử nằm theo chiều DỌC, tức là vạch T và C phải nằm trên cùng một trục dọc (vạch này nằm trên đầu vạch kia).
   -> Advice: "Que thử đang nằm ngang. Vui lòng xoay điện thoại hoặc que thử để nó nằm theo chiều DỌC (Vạch T ở trên vạch C)."
5. **Sai hướng ký tự (Rotated Text)**:
   - Hình ảnh que thử nằm dọc, nhưng các ký tự đánh dấu trên vỏ nhựa (như chữ "C", "T", "S", "LH"...) lại bị xoay ngang (90 độ) so với hướng nhìn thẳng.
   - Nguyên tắc: Chữ viết phải đứng thẳng, đọc được bình thường từ trái sang phải, không bắt người đọc phải nghiêng đầu.
   -> Advice: "Hướng que thử chưa đúng (chữ C/T bị xoay ngang). Vui lòng xoay ảnh hoặc que thử sao cho chữ hiển thị thẳng đứng.
6. **Vùng hiển thị trống/Bất thường (Empty/Missing Strip)**:
   - Cửa sổ đọc kết quả hoàn toàn trắng trơn hoặc nhìn thấy đáy nhựa, không có bất kỳ vạch màu hay dấu hiệu đã thấm mẫu thử nào.
   -> Advice: "Cửa sổ hiển thị trống rỗng. Que thử có thể chưa sử dụng hoặc bị thiếu lõi thử bên trong."
         
**GIAI ĐOẠN 2: PHÂN TÍCH KẾT QUẢ (Chỉ thực hiện khi Giai đoạn 1 hợp lệ)**
Nếu hình ảnh đạt chuẩn (Rõ nét, đủ sáng, NẰM DỌC), hãy tiến hành đọc kết quả theo thứ tự ưu tiên:
1. **Xác thực hình ảnh**: Đây có phải là ảnh que thử không? Nếu không, trả về kết quả "UNKNOWN".
2. **Vạch Đối chứng (C)**: Xác định vị trí vạch C. Nó phải là một vạch màu rõ nét. Nếu không thấy vạch C -> trả về "LỖI".
3. **Vạch Kết quả (T)**: Quan sát kỹ vùng T.
   - Tìm bất kỳ vạch màu nào (hồng/đỏ), kể cả khi **cực kỳ mờ**.
   - Phân biệt vạch thật với vết xước, bóng đổ hoặc vết bẩn (thường không có màu nhuộm hồng đặc trưng).

**Quy tắc Logic & Định nghĩa**:
- **Ước lượng chỉ số LH (LH Value)**:
  - Nếu thấy C nhưng T rất mờ hoặc không thấy: LH khoảng 0-30 mIU/mL.
  - Nếu T hiện rõ và đậm tương đương vạch C: LH khoảng 30-50 mIU/mL.
  - Nếu T đậm hơn hẳn vạch C hoặc đỏ thẫm: LH > 50 mIU/mL.

- **Phân loại Trạng thái (Status)**:
  - **THẤP**: Nếu chỉ số LH ước lượng <= 30.
  - **CAO**: Nếu chỉ số LH ước lượng <= 60.
  - **ĐẠT ĐỈNH**: Nếu chỉ số LH ước lượng > 60.
  - **LỖI**: Nếu không thấy vạch C.
  - **UNKNOWN**: Hình ảnh không hợp lệ hoặc quá mờ.

**Hướng dẫn đưa ra lời khuyên (Advice)**:
- Nếu **THẤP**: "Nồng độ LH thấp. Tiếp tục theo dõi."
- Nếu **CAO**: "Nồng độ LH rất cao. Trứng có thể đã rụng hoặc đang trong quá trình rụng. Hãy theo dõi thêm."
- Nếu **ĐẠT ĐỈNH**: "Nồng độ LH đang tăng cao (Đạt đỉnh). Trứng có thể rụng trong 24-48h tới. Nên thử lại sau 4h."
- Nếu **LỖI**: "Que thử bị lỗi hoặc không đọc được. Vui lòng thử lại với que khác."

**Định dạng đầu ra**:
Chỉ trả về một đối tượng JSON thuần túy (không dùng markdown, không code block) với cấu trúc sau:
{
  "lh_value": <estimated_integer_value_0_to_100+>,
  "status": "THẤP" | "ĐẠT ĐỈNH" | "CAO" | "LỖI" | "UNKNOWN",
  "advice": "<Brief advice in Vietnamese>",
  "confidence": <number_0_to_100>
}
"""),
          DataPart('image/jpeg', imageBytes),
        ])
      ];

      // 3. Gửi request
      final response = await model.generateContent(content);

      // 4. Xử lý kết quả
      final jsonResponse = jsonDecode(response.text ?? '{}');

      int lhValue = jsonResponse['lh_value'] ?? 0;
      String status = jsonResponse['status'] ??
          'UNKNOWN'; // Đảm bảo lấy giá trị mặc định hợp lý
      String advice = jsonResponse['advice'] ?? 'Không thể phân tích ảnh.';
      int confidence = jsonResponse['confidence'] ?? 0;

// --- LOGIC PHÂN LOẠI MÀU SẮC THEO STATUS MỚI ---
      Color statusColor;
      switch (status) {
        case "THẤP":
          statusColor = Colors.green; // Màu xanh lá cho nồng độ thấp
          break;
        case "ĐẠT ĐỈNH":
          statusColor = Colors.orange; // Màu cam cho giai đoạn quan trọng
          break;
        case "CAO":
          statusColor = Colors.red; // Màu đỏ cho nồng độ rất cao
          break;
        case "LỖI":
          statusColor = Colors.grey; // Màu xám cho lỗi
          break;
        default: // UNKNOWN hoặc lỗi không mong muốn
          statusColor = Colors.blueGrey;
      }

      setState(() {
        // Cập nhật lại _resultText nếu bạn dùng nó để hiển thị
        // Hoặc gọi dialog như hướng dẫn bên dưới
        _resultText = "Đang chờ hiển thị chi tiết..."; // Placeholder
      });

// Hiển thị Dialog hoặc cập nhật UI đẹp hơn
      _showResultDialog(lhValue, status, advice, statusColor, confidence);
    } catch (e) {
      setState(() {
        _resultText = "Lỗi: $e";
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _showResultDialog(
      int value, String status, String advice, Color color, int conf) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.waves, color: color), // Icon sóng LH
            SizedBox(width: 10),
            Text("Kết quả LH", style: TextStyle(fontWeight: FontWeight.bold)),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Hiển thị số LH ước lượng
            Text(
              "$value",
              style: TextStyle(
                  fontSize: 60, fontWeight: FontWeight.bold, color: color),
            ),
            Text("mIU/mL", style: TextStyle(color: Colors.grey)),
            SizedBox(height: 20),

            // Hiển thị trạng thái
            Container(
              padding: EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                status.toUpperCase(), // Luôn hiển thị in hoa cho nổi bật
                style: TextStyle(
                    color: color, fontWeight: FontWeight.bold, fontSize: 18),
              ),
            ),
            SizedBox(height: 15),

            // Lời khuyên
            Text(
              advice,
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
            SizedBox(height: 10),
            Text("Độ tin cậy AI: $conf%",
                style: TextStyle(fontSize: 10, color: Colors.grey)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text("Đóng"),
          ),
        ],
      ),
    );
  }

  Future<void> _pickImage(ImageSource source) async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: source);
    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _resultText = "Nhấn nút Phân tích để xem kết quả";
      });
    }
  }

// --- HÀM MỚI: Xử lý lấy ảnh từ Assets ---
  Future<void> _loadAssetImage(String assetPath) async {
    try {
      print("Đang tìm file: $assetPath");
      // 1. Load bytes từ assets
      final byteData = await rootBundle.load(assetPath);

      // 2. Tạo file tạm thời (Temp File)
      final fileName = assetPath.split('/').last;
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/$fileName');

      // 3. Ghi dữ liệu vào file
      await tempFile.writeAsBytes(byteData.buffer.asUint8List(
        byteData.offsetInBytes,
        byteData.lengthInBytes,
      ));

      // 4. Cập nhật UI
      setState(() {
        _image = tempFile;
        _resultText = "Đã chọn ảnh $fileName. Nhấn Phân tích.";
      });
    } catch (e) {
      print("Lỗi load asset: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Không tìm thấy ảnh trong  $assetPath")),
      );
    }
  }

  // --- HÀM 2: Hiển thị Bottom Sheet ---
  void _showAssetBottomSheet() {
    showModalBottomSheet(
      context: context,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(16),
          height: 500,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                "Chọn ảnh mẫu",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: sampleImages.length,
                  separatorBuilder: (ctx, i) => Divider(),
                  itemBuilder: (context, index) {
                    final path = sampleImages[index];
                    final name = path.split('/').last;

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.asset(
                          path,
                          width: 50,
                          height: 50,
                          fit: BoxFit.cover,
                          errorBuilder: (c, o, s) => Icon(Icons.broken_image),
                        ),
                      ),
                      title: Text(name),
                      subtitle: Text(path,
                          style: TextStyle(fontSize: 12, color: Colors.grey)),
                      onTap: () {
                        Navigator.pop(context); // Đóng sheet
                        _loadAssetImage(path); // Load ảnh
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print('$_resultText');
    return Scaffold(
      appBar: AppBar(title: Text("AI Đọc Que Thử")),
      body: Column(
        children: [
          Expanded(
            child: Center(
              child: _image == null
                  ? Text("Vui lòng chụp ảnh que thử")
                  : Image.file(_image!),
            ),
          ),
          Text(_resultText,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center),
          SizedBox(height: 20),
          if (_isLoading) CircularProgressIndicator(),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildButton(Icons.camera_alt, "Camera",
                  () => _pickImage(ImageSource.camera), Colors.blue),
              _buildButton(Icons.photo_library, "Thư viện",
                  () => _pickImage(ImageSource.gallery), Colors.blue),
            ],
          ),
          SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              // NÚT MỞ BOTTOM SHEET
              _buildButton(Icons.folder_copy, "Ảnh mẫu (Asset)",
                  _showAssetBottomSheet, Colors.orange),

              // NÚT PHÂN TÍCH
              _buildButton(
                  Icons.analytics, "Phân tích", _analyzeImage, Colors.green),
            ],
          ),
          SizedBox(height: 30),
        ],
      ),
    );
  }

  Widget _buildButton(IconData icon, String label, VoidCallback onPressed,
      MaterialColor color) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: color.shade50,
        foregroundColor: color.shade900,
        iconColor: color,
      ),
      icon: Icon(icon),
      label: Text(label),
      onPressed: onPressed,
    );
  }
}
