part of '../trolley_brand.dart';

final _handle = Path()
  ..moveTo(116, 122)
  ..lineTo(116, 91)
  ..quadraticBezierTo(116, 81, 126, 81)
  ..lineTo(170, 81)
  ..quadraticBezierTo(180, 81, 180, 91)
  ..lineTo(180, 122);
final _inner = Path()
  ..moveTo(116, 150)
  ..cubicTo(116, 177, 132, 175, 155, 175)
  ..lineTo(168, 175)
  ..cubicTo(190, 175, 190, 194, 168, 202)
  ..lineTo(136, 214)
  ..cubicTo(111, 225, 130, 232, 149, 232)
  ..lineTo(179, 232);
final List<_Segment> _segments = [
  _Segment(
      Path()
        ..moveTo(179, 232)
        ..cubicTo(214, 273, 245, 244, 235, 196)
        ..cubicTo(225, 148, 242, 109, 267, 130),
      true),
  _Segment(
      Path()
        ..moveTo(267, 130)
        ..lineTo(267, 156)
        ..lineTo(248, 156)
        ..lineTo(289, 156)
        ..lineTo(267, 156)
        ..lineTo(267, 193)
        ..quadraticBezierTo(267, 214, 290, 210),
      false),
  _Segment(
      Path()
        ..moveTo(290, 210)
        ..quadraticBezierTo(306, 228, 321, 211),
      true),
  _Segment(
      Path()
        ..moveTo(321, 211)
        ..lineTo(321, 172)
        ..quadraticBezierTo(321, 149, 347, 152),
      false),
  _Segment(
      Path()
        ..moveTo(347, 152)
        ..quadraticBezierTo(370, 125, 400, 151),
      true),
  _Segment(
      Path()
        ..moveTo(400, 151)
        ..cubicTo(355, 151, 355, 212, 400, 212)
        ..cubicTo(445, 212, 445, 151, 400, 151),
      false),
  _Segment(
      Path()
        ..moveTo(400, 151)
        ..quadraticBezierTo(430, 77, 461, 118),
      true),
  _Segment(
      Path()
        ..moveTo(461, 118)
        ..lineTo(461, 211),
      false),
  _Segment(
      Path()
        ..moveTo(461, 211)
        ..cubicTo(469, 248, 491, 244, 488, 186)
        ..cubicTo(485, 128, 493, 101, 506, 118),
      true),
  _Segment(
      Path()
        ..moveTo(506, 118)
        ..lineTo(506, 211),
      false),
  _Segment(
      Path()
        ..moveTo(506, 211)
        ..quadraticBezierTo(534, 241, 545, 181),
      true),
  _Segment(
      Path()
        ..moveTo(545, 181)
        ..lineTo(602, 181)
        ..cubicTo(602, 142, 545, 140, 545, 181)
        ..cubicTo(545, 210, 577, 222, 599, 205),
      false),
  _Segment(
      Path()
        ..moveTo(599, 205)
        ..quadraticBezierTo(616, 238, 635, 158),
      true),
  _Segment(
      Path()
        ..moveTo(635, 158)
        ..lineTo(635, 183)
        ..quadraticBezierTo(635, 210, 660, 210)
        ..quadraticBezierTo(685, 210, 685, 183)
        ..lineTo(685, 158)
        ..lineTo(685, 225)
        ..quadraticBezierTo(685, 258, 647, 252),
      false),
];
