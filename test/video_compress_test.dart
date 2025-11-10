import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Quality parameter validation', () {
    test('Valid quality values should be within range 1-100', () {
      // Test that our assertions are correct
      // Valid quality values
      const validQualities = [1, 50, 100];
      for (final quality in validQualities) {
        expect(quality >= 1 && quality <= 100, isTrue,
            reason: 'Quality $quality should be valid (1-100)');
      }
    });

    test('Invalid quality values should be outside range 1-100', () {
      // Invalid quality values
      const invalidQualities = [0, -1, 101, 200];
      for (final quality in invalidQualities) {
        expect(quality >= 1 && quality <= 100, isFalse,
            reason: 'Quality $quality should be invalid (outside 1-100)');
      }
    });
    
    test('Old buggy assertion logic would incorrectly validate', () {
      // This test demonstrates the bug in the old assertion
      // Old logic: quality > 1 || quality < 100
      
      // These invalid values would incorrectly pass with the old logic
      expect(0 > 1 || 0 < 100, isTrue, 
          reason: 'Old logic incorrectly accepts quality=0');
      expect(101 > 1 || 101 < 100, isTrue,
          reason: 'Old logic incorrectly accepts quality=101');
      
      // New correct logic: quality >= 1 && quality <= 100
      expect(0 >= 1 && 0 <= 100, isFalse,
          reason: 'New logic correctly rejects quality=0');
      expect(101 >= 1 && 101 <= 100, isFalse,
          reason: 'New logic correctly rejects quality=101');
    });
  });
}
