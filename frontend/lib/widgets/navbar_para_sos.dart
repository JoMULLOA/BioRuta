import 'package:flutter/material.dart';
import '../navbar_widget.dart';

class NavbarParaSOS extends StatelessWidget {
  final int currentIndex;
  final Function(int) onTap;
  final VoidCallback? onSOSLongPress; // Callback para long press en SOS

  const NavbarParaSOS({
    Key? key,
    required this.currentIndex,
    required this.onTap,
    this.onSOSLongPress, // Callback opcional
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Para la pantalla SOS, siempre mostrar SOS en el medio y marcarlo como activo
    return CustomNavbar(
      currentIndex: 3, // SOS está en el índice 3 (en el medio)
      onTap: (index) {
        if (index == 3) {
          // Si toca SOS, no hacer nada porque ya estamos en SOS
          return;
        }
        // Para otros índices, ajustar y llamar onTap
        int adjustedIndex = index;
        if (index > 3) {
          adjustedIndex = index - 1; // Ajustar índices después de SOS
        }
        onTap(adjustedIndex);
      },
      showSOS: true, // Siempre mostrar SOS
      onSOSLongPress: onSOSLongPress, // Pasar el callback
    );
  }
}
