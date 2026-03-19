import 'dart:async';
import 'dart:developer' as dev;
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;

/// code tối ưu theo cách mới tối ưu sang color lab
/// Chuyển đổi từ RGB sang không gian màu Lab.
/// Tham số:
/// - [r]: Giá trị Red (0-255)
/// - [g]: Giá trị Green (0-255)
/// - [b]: Giá trị Blue (0-255)
/// Trả về:
/// - Giá trị Lab dạng double.
class ImageAnalyze {
  // Chuyển đổi ảnh từ RGB sang Lab
  Future<Map<int, double>> convertRGBToLab(img.Image image,
      {double scale = 0.5}) async {
    final resizedImage = img.copyResize(image,
        width: (image.width * scale).round(),
        height: (image.height * scale).round());

    Map<int, double> labMap = {};
    for (int y = 0; y < resizedImage.height; y++) {
      for (int x = 0; x < resizedImage.width; x++) {
        final int pixel = resizedImage.getPixel(x, y);
        final Color color = Color(pixel);
        final labColor = rgbToLab(color.red, color.green, color.blue);
        labMap[pixel] = labColor;
      }
    }
    return labMap;
  }

  // Chuyển đổi RGB sang Lab (đơn giản hóa)
  double rgbToLab(int r, int g, int b) {
    // Chuyển đổi từ RGB sang không gian màu XYZ
    double xr = r / 255.0;
    double xg = g / 255.0;
    double xb = b / 255.0;

    xr = xr > 0.04045 ? pow((xr + 0.055) / 1.055, 2.4) as double : xr / 12.92;
    xg = xg > 0.04045 ? pow((xg + 0.055) / 1.055, 2.4) as double : xg / 12.92;
    xb = xb > 0.04045 ? pow((xb + 0.055) / 1.055, 2.4) as double : xb / 12.92;

    double x = xr * 0.4124 + xg * 0.3576 + xb * 0.1805;
    double y = xr * 0.2126 + xg * 0.7152 + xb * 0.0722;
    double z = xr * 0.0193 + xg * 0.1192 + xb * 0.9505;

    // Chuyển đổi từ XYZ sang Lab
    double l = 116.0 * _f(y / 1.0) - 16.0;
    double a = 500.0 * (_f(x / 0.9505) - _f(y / 1.0));
    double b_ = 200.0 * (_f(y / 1.0) - _f(z / 1.089));

    return sqrt(l * l + a * a + b_ * b_);
  }

  double _f(double t) {
    return t > 0.008856
        ? pow(t, 1.0 / 3.0) as double
        : (7.787 * t) + (16.0 / 116.0);
  }

  // Cắt ảnh để lấy 2 vạch so sánh tính ra nồng độ LH
  Future<img.Image> cropImage(img.Image image) async {
    final int newWidth = image.width ~/ 10;
    final int newHeight = image.height ~/ 3.5;

    final int startX = (image.width - newWidth) ~/ 2;
    final int startY = (image.height - newHeight) ~/ 2;
    final img.Image croppedImage = img.copyCrop(
      image,
      startX,
      startY,
      newWidth,
      newHeight,
    );

    return croppedImage;
  }

// Tách ảnh ra làm 3 phần bằng nhau
  Future<SplitImage?> splitImage(img.Image inputImage) async {
    try {
      img.Image croppedImage = await cropImage(inputImage);
      List<Color> listColor = [];
      List<img.Image> listImage = [];
      final int width = croppedImage.width;
      final int height = croppedImage.height;
      final int splitHeight = height ~/ 3;

      for (int i = 0; i < 3; i++) {
        final img.Image splitImage =
            img.copyCrop(croppedImage, 0, i * splitHeight, width, splitHeight);
        listImage.add(splitImage);
        Map<int, double> labMap = await convertRGBToLab(splitImage);
        Color? color = await getAverageColorFromLab(labMap);

        if (color == null) {
          return null;
        }
        listColor.add(color);
      }

      int accuracy = await calculateLHColor(listColor);
      double diff1 = calculateCIEDE2000Distance(listColor[1], listColor[0]);
      double diff2 = calculateCIEDE2000Distance(listColor[1], listColor[2]);

      return SplitImage(
          images: listImage, lh: accuracy, diff1: diff1, diff2: diff2);
    } catch (e) {
      dev.log('ERROR : ${e.toString()}');
      return null;
    }
  }

  // Lấy màu trung bình dựa trên Lab
  Future<Color?> getAverageColorFromLab(Map<int, double> labMap) async {
    if (labMap.isEmpty) return null;

    int totalRed = 0;
    int totalGreen = 0;
    int totalBlue = 0;
    int count = 0;

    labMap.forEach((pixel, _) {
      totalRed += img.getRed(pixel);
      totalGreen += img.getGreen(pixel);
      totalBlue += img.getBlue(pixel);
      count++;
    });

    Color averageColor = Color.fromRGBO(
      totalRed ~/ count,
      totalGreen ~/ count,
      totalBlue ~/ count,
      1.0,
    );

    return averageColor;
  }

  // Tính độ chênh lệch màu sắc bằng CIEDE2000
  double calculateCIEDE2000Distance(Color color1, Color color2) {
    final lab1 = rgbToLab(color1.red, color1.green, color1.blue);
    final lab2 = rgbToLab(color2.red, color2.green, color2.blue);
    return (lab1 - lab2).abs();
  }

  // Tính độ LH theo color
  Future<int> calculateLHColor(List<Color> list) async {
    double diff1 = calculateCIEDE2000Distance(list[1], list[0]);
    double diff2 = calculateCIEDE2000Distance(list[1], list[2]);
    dev.log("Diff1: $diff1, Diff2: $diff2"); // Log giá trị diff

    double ratio = (diff1 / (diff2 + 1e-6)) * 100 * 0.8;
    int res = ratio.round();

    print('RES- ${res.toString()}');

    // Điều chỉnh nồng độ LH dựa trên kết quả
    if (res < 0) {
      res = diff1 > 40 ? 80 : (diff1 <= 3 ? 3 : diff1.round());
    } else if (res <= 1) {
      res = 3;
    } else if (res > 80) {
      res = 80;
    }
    dev.log("Calculated LH: $res mIU/mL");
    return res;
  }
}

class SplitImage {
  final List<img.Image> images;
  final int lh;
  double diff1;
  double diff2;

  SplitImage({
    required this.images,
    required this.lh,
    this.diff1 = 0,
    this.diff2 = 0,
  });
}
