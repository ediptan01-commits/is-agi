import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Alt gezinme çubuğu ekran yüksekliğini kaplamaz', () {
    final source = File('lib/main.dart').readAsStringSync();
    expect(source.contains('bottomNavigationBar:SafeArea(top:false,child:SizedBox(height:76'), isTrue);
    expect(source.contains('Expanded(child:SizedBox(height:64,child:Center(child:FloatingActionButton.small'), isTrue);
  });
}
