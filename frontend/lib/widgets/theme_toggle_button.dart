import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/theme_provider.dart';
import '../config/app_colors.dart';

class ThemeToggleButton extends StatelessWidget {
  const ThemeToggleButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return FloatingActionButton(
          mini: true,
          backgroundColor: themeProvider.isDarkMode 
              ? AppColors.darkSurface 
              : AppColors.primaryLight,
          onPressed: () {
            themeProvider.toggleTheme();
          },
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: Icon(
              themeProvider.isDarkMode 
                  ? Icons.light_mode 
                  : Icons.dark_mode,
              key: ValueKey(themeProvider.isDarkMode),
              color: themeProvider.isDarkMode 
                  ? AppColors.primaryLight 
                  : Colors.white,
            ),
          ),
        );
      },
    );
  }
}

// Botón más grande para usar en configuraciones
class ThemeToggleSwitch extends StatelessWidget {
  const ThemeToggleSwitch({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Consumer<ThemeProvider>(
      builder: (context, themeProvider, child) {
        return Container(
          width: 100,
          height: 50,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(25),
            gradient: LinearGradient(
              colors: themeProvider.isDarkMode
                  ? [AppColors.darkSurface, AppColors.primaryDark]
                  : [AppColors.primaryLight, AppColors.primaryLight],
            ),
          ),
          child: Stack(
            children: [
              AnimatedPositioned(
                duration: const Duration(milliseconds: 300),
                left: themeProvider.isDarkMode ? 50 : 0,
                child: Container(
                  width: 50,
                  height: 50,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    themeProvider.isDarkMode 
                        ? Icons.dark_mode 
                        : Icons.light_mode,
                    color: themeProvider.isDarkMode 
                        ? AppColors.darkBackground 
                        : AppColors.primaryLight,
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => themeProvider.toggleTheme(),
                child: Container(
                  width: 100,
                  height: 50,
                  color: Colors.transparent,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}