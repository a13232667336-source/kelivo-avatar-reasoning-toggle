import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

/// WeChat-style markup sheet shown right after a picture is picked.
///
/// The point of this screen is the pen: pick a colour, draw on the photo,
/// undo, done. Cancelling returns the untouched original.
class ImageAnnotatePage extends StatefulWidget {
  const ImageAnnotatePage({super.key, required this.sourcePath});

  final String sourcePath;

  /// Opens the editor. Returns the annotated file path, or `null` when the user
  /// chose "原图" (use the original picture as picked).
  static Future<String?> open(BuildContext context, String path) {
    return Navigator.of(context).push<String>(
      MaterialPageRoute<String>(
        builder: (_) => ImageAnnotatePage(sourcePath: path),
        fullscreenDialog: true,
      ),
    );
  }

  @override
  State<ImageAnnotatePage> createState() => _ImageAnnotatePageState();
}

class _AnnotateStroke {
  _AnnotateStroke({required this.color, required this.width})
    : points = <Offset>[];

  final Color color;
  final double width;
  final List<Offset> points;
}

class _ImageAnnotatePageState extends State<ImageAnnotatePage> {
  static const List<Color> _palette = <Color>[
    Color(0xFFFFFFFF),
    Color(0xFFFF3B30),
    Color(0xFFFFCC00),
    Color(0xFF34C759),
    Color(0xFF0A84FF),
    Color(0xFF000000),
  ];
  static const List<double> _widths = <double>[3, 6, 12];

  final GlobalKey _boundaryKey = GlobalKey();
  final List<_AnnotateStroke> _strokes = <_AnnotateStroke>[];

  late final File _file = File(widget.sourcePath);
  ui.Size? _imageSize;
  Color _color = _palette[0];
  double _width = _widths[1];
  _AnnotateStroke? _active;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _resolveImageSize();
  }

  Future<void> _resolveImageSize() async {
    try {
      final bytes = await _file.readAsBytes();
      final codec = await ui.instantiateImageCodec(bytes);
      final frame = await codec.getNextFrame();
      if (!mounted) return;
      setState(() => _imageSize = frame.image.width == 0
          ? null
          : ui.Size(
              frame.image.width.toDouble(),
              frame.image.height.toDouble(),
            ));
    } catch (_) {
      // Fall back to a square box; drawing still works.
    }
  }

  Size _fitted(Size available) {
    final image = _imageSize;
    if (image == null || image.width <= 0 || image.height <= 0) {
      final side = available.shortestSide;
      return Size(side, side);
    }
    final scale = (available.width / image.width) <
            (available.height / image.height)
        ? available.width / image.width
        : available.height / image.height;
    return Size(image.width * scale, image.height * scale);
  }

  void _startStroke(Offset local) {
    final stroke = _AnnotateStroke(color: _color, width: _width)
      ..points.add(local);
    setState(() {
      _active = stroke;
      _strokes.add(stroke);
    });
  }

  void _extendStroke(Offset local) {
    final stroke = _active;
    if (stroke == null) return;
    setState(() => stroke.points.add(local));
  }

  void _endStroke() {
    _active = null;
  }

  void _undo() {
    if (_strokes.isEmpty) return;
    setState(() => _strokes.removeLast());
  }

  Future<void> _finish() async {
    if (_exporting) return;
    if (_strokes.isEmpty) {
      Navigator.of(context).pop(null);
      return;
    }
    setState(() => _exporting = true);
    try {
      final boundary =
          _boundaryKey.currentContext?.findRenderObject()
              as RenderRepaintBoundary?;
      if (boundary == null) {
        Navigator.of(context).pop(null);
        return;
      }
      final image = await boundary.toImage(pixelRatio: 2);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        if (mounted) Navigator.of(context).pop(null);
        return;
      }
      final dir = await getTemporaryDirectory();
      final out = File(
        '${dir.path}/annotated_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await out.writeAsBytes(data.buffer.asUint8List(), flush: true);
      if (mounted) Navigator.of(context).pop(out.path);
    } catch (_) {
      if (mounted) Navigator.of(context).pop(null);
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            _topBar(context),
            Expanded(
              child: Center(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final size = _fitted(constraints.biggest);
                    return RepaintBoundary(
                      key: _boundaryKey,
                      child: SizedBox(
                        width: size.width,
                        height: size.height,
                        child: Stack(
                          fit: StackFit.expand,
                          children: [
                            Image.file(
                              _file,
                              fit: BoxFit.cover,
                              gaplessPlayback: true,
                            ),
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onPanStart: (d) => _startStroke(d.localPosition),
                              onPanUpdate: (d) => _extendStroke(d.localPosition),
                              onPanEnd: (_) => _endStroke(),
                              onPanCancel: _endStroke,
                              child: CustomPaint(
                                painter: _StrokePainter(
                                  strokes: _strokes,
                                  active: _active,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            _toolbar(context),
          ],
        ),
      ),
    );
  }

  Widget _topBar(BuildContext context) {
    const style = TextStyle(color: Colors.white, fontSize: 16);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Row(
        children: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(null),
            child: const Text('原图', style: style),
          ),
          const Spacer(),
          if (_strokes.isNotEmpty)
            IconButton(
              onPressed: _undo,
              tooltip: '撤销',
              icon: const Icon(Icons.undo, color: Colors.white),
            ),
          TextButton(
            onPressed: _exporting ? null : _finish,
            child: Text(
              '完成',
              style: style.copyWith(
                color: const Color(0xFF34C759),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              for (final color in _palette)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: GestureDetector(
                    onTap: () => setState(() => _color = color),
                    child: Container(
                      width: 26,
                      height: 26,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _color == color
                              ? Colors.white
                              : Colors.white.withValues(alpha: 0.25),
                          width: _color == color ? 2.5 : 1,
                        ),
                      ),
                    ),
                  ),
                ),
              const Spacer(),
              for (final width in _widths)
                GestureDetector(
                  onTap: () => setState(() => _width = width),
                  child: Container(
                    margin: const EdgeInsets.only(left: 8),
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: _width == width
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Container(
                      width: width + 2,
                      height: width + 2,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const Icon(
                Icons.brush,
                color: Color(0xFF34C759),
                size: 18,
              ),
              const SizedBox(width: 6),
              Text(
                '在图片上涂抹即可标记',
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.55),
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _StrokePainter extends CustomPainter {
  _StrokePainter({required this.strokes, required this.active});

  final List<_AnnotateStroke> strokes;
  final _AnnotateStroke? active;

  @override
  void paint(Canvas canvas, Size size) {
    for (final stroke in strokes) {
      if (stroke.points.isEmpty) continue;
      final paint = Paint()
        ..color = stroke.color
        ..strokeWidth = stroke.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      if (stroke.points.length == 1) {
        canvas.drawCircle(
          stroke.points.first,
          stroke.width / 2,
          paint..style = PaintingStyle.fill,
        );
        continue;
      }
      final path = Path()
        ..moveTo(stroke.points.first.dx, stroke.points.first.dy);
      for (var i = 1; i < stroke.points.length; i++) {
        path.lineTo(stroke.points[i].dx, stroke.points[i].dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(_StrokePainter oldDelegate) => true;
}
