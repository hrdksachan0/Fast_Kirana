# Canvas UI Rules & Best Practices

## Rendering & CustomPainter Rules
1. **Always wrap custom painted animated widgets in `RepaintBoundary`** to prevent entire widget tree repaints.
2. **Implement efficient `shouldRepaint`** logic in every `CustomPainter` to only redraw when actual parameters change.
3. **Use anti-aliasing** (`Paint()..isAntiAlias = true`) for smooth diagonal lines, circles, and rounded path borders.
4. **Prefer hardware-accelerated shaders and canvas paths** over nested complex widget hierarchies for high-performance visual effects.
