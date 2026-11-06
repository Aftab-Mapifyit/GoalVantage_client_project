import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import '../theme/app_colors.dart';
import '../utils/breakpoints.dart';
import 'responsive.dart';
import 'core_widgets.dart';

/// Compact: form only. Expanded: branding panel left + form right (like web).
class AuthScaffold extends StatelessWidget {
  final Widget form;
  final String headline;
  final String sub;
  AuthScaffold({super.key, required this.form, required this.headline, required this.sub});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: ResponsiveBuilder(
        builder: (context, size) {
          if (!size.isExpanded) {
            return SafeArea(child: SingleChildScrollView(padding: Responsive.pagePadding(context), child: form));
          }
          return Row(
            children: [
              // Branding panel
              Expanded(
                flex: 55,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft, end: Alignment.bottomRight,
                      colors: [Color(0xFF0A0C14), Color(0xFF05060A)],
                    ),
                  ),
                  child: ConstrainedContent(
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          LogoMark(size: 44),
                          SizedBox(height: 32),
                          Text(headline, style: TextStyle(color: AppColors.foreground, fontSize: 40, fontWeight: FontWeight.w700, letterSpacing: -1, height: 1.1)),
                          SizedBox(height: 16),
                          Text(sub, style: TextStyle(color: AppColors.foregroundSecondary, fontSize: 15, height: 1.6)),
                          SizedBox(height: 32),
                          Wrap(
                            spacing: 10, runSpacing: 10,
                            children: [
                              _Chip(icon: LucideIcons.key, label: 'Non-custodial'),
                              _Chip(icon: LucideIcons.shield, label: 'Fair Routing'),
                              _Chip(icon: LucideIcons.code, label: 'Open source'),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              VerticalDivider(width: 1, color: AppColors.border),
              // Form panel
              Expanded(
                flex: 45,
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: 460),
                    child: SingleChildScrollView(
                      padding: EdgeInsets.all(40),
                      child: form,
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final IconData icon; final String label;
  _Chip({required this.icon, required this.label});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(color: AppColors.card, borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.border)),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 13, color: AppColors.positive),
        SizedBox(width: 6),
        Text(label, style: TextStyle(color: AppColors.foregroundSecondary, fontSize: 11, fontWeight: FontWeight.w600)),
      ]),
    );
  }
}