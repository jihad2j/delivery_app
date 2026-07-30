import 'package:flutter/material.dart';
import '../core/theme.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool showBackButton;
  final bool centerTitle;
  final Color? backgroundColor;
  final Color? titleColor;
  final double elevation;

  const CustomAppBar({
    super.key,
    required this.title,
    this.actions,
    this.leading,
    this.showBackButton = true,
    this.centerTitle = true,
    this.backgroundColor,
    this.titleColor,
    this.elevation = 0,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return AppBar(
      title: Text(
        title,
        style: TextStyle(
          color:
              titleColor ??
              (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary),
          fontWeight: FontWeight.w700,
          fontSize: 18,
          fontFamily: AppTheme.fontFamily,
        ),
      ),
      centerTitle: centerTitle,
      elevation: elevation,
      scrolledUnderElevation: 1,
      backgroundColor: backgroundColor ?? Colors.transparent,
      surfaceTintColor: Colors.transparent,
      leading:
          leading ??
          (showBackButton
              ? IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
                  onPressed: () => Navigator.of(context).pop(),
                )
              : null),
      actions: actions,
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? padding;
  final double? titleSize;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.trailing,
    this.padding,
    this.titleSize,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding ?? const EdgeInsets.fromLTRB(4, 4, 4, 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.headlineSmall?.copyWith(fontSize: titleSize),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    subtitle!,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ],
            ),
          ),
          // ignore: use_null_aware_elements
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class StatusBadge extends StatelessWidget {
  final String label;
  final Color? color;
  final double? fontSize;
  final EdgeInsetsGeometry? padding;
  final IconData? icon;

  const StatusBadge({
    super.key,
    required this.label,
    this.color,
    this.fontSize,
    this.padding,
    this.icon,
  });

  factory StatusBadge.fromStatus(String status, {double? fontSize}) {
    return StatusBadge(
      label: AppTheme.getStatusText(status),
      color: AppTheme.getStatusColor(status),
      fontSize: fontSize,
    );
  }

  @override
  Widget build(BuildContext context) {
    final badgeColor = color ?? AppColors.info;
    return Container(
      padding:
          padding ?? const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: AppTheme.statusBadge(badgeColor),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: badgeColor),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontFamily: AppTheme.fontFamily,
              fontSize: fontSize ?? 11,
              fontWeight: FontWeight.w700,
              color: badgeColor,
            ),
          ),
        ],
      ),
    );
  }
}

class GradientCard extends StatelessWidget {
  final Widget child;
  final BoxDecoration? gradient;
  final EdgeInsetsGeometry? padding;
  final VoidCallback? onTap;
  final double? height;
  final double? width;

  const GradientCard({
    super.key,
    required this.child,
    this.gradient,
    this.padding,
    this.onTap,
    this.height,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(24),
        child: Ink(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(20),
          decoration: gradient ?? AppTheme.primaryGradient(),
          child: child,
        ),
      ),
    );
  }
}

class StatCard extends StatelessWidget {
  final String title;
  final String value;
  final IconData icon;
  final Color color;
  final VoidCallback? onTap;

  const StatCard({
    super.key,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Ink(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withValues(alpha: 0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(icon, color: color, size: 20),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                title,
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 4),
              Text(
                value,
                style: Theme.of(context).textTheme.displaySmall?.copyWith(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class InfoListTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? iconColor;
  final Widget? trailing;

  const InfoListTile({
    super.key,
    required this.icon,
    required this.label,
    required this.value,
    this.iconColor,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final tileColor = iconColor ?? AppColors.primary;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: tileColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: tileColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: Theme.of(context).textTheme.labelSmall),
                const SizedBox(height: 2),
                Text(
                  value,
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontSize: 13),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          // ignore: use_null_aware_elements
          if (trailing != null) trailing!,
        ],
      ),
    );
  }
}

class LoadingIndicator extends StatelessWidget {
  final String? message;
  final double size;
  final Color? color;

  const LoadingIndicator({super.key, this.message, this.size = 36, this.color});

  @override
  Widget build(BuildContext context) {
    final loaderColor = color ?? AppColors.primary;
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: CircularProgressIndicator(
              valueColor: AlwaysStoppedAnimation<Color>(loaderColor),
              strokeWidth: 3,
            ),
          ),
          if (message != null) ...[
            const SizedBox(height: 14),
            Text(
              message!,
              style: Theme.of(context).textTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ],
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? description;
  final Widget? actionButton;
  final double iconSize;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.description,
    this.actionButton,
    this.iconSize = 64,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              padding: EdgeInsets.all(iconSize * 0.3),
              decoration: BoxDecoration(
                color: (isDark
                    ? AppColors.darkSurface
                    : AppColors.lightSurface),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (description != null) ...[
              const SizedBox(height: 8),
              Text(
                description!,
                style: Theme.of(context).textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (actionButton != null) ...[
              const SizedBox(height: 24),
              actionButton!,
            ],
          ],
        ),
      ),
    );
  }
}

class ChipSelector<T> extends StatelessWidget {
  final List<T> items;
  final T selected;
  final String Function(T item) labelBuilder;
  final ValueChanged<T> onSelected;
  final double? height;

  const ChipSelector({
    super.key,
    required this.items,
    required this.selected,
    required this.labelBuilder,
    required this.onSelected,
    this.height,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height ?? 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: items.length,
        separatorBuilder: (context, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          final isSelected = selected == item;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          return ChoiceChip(
            label: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              child: Text(labelBuilder(item)),
            ),
            selected: isSelected,
            onSelected: (_) => onSelected(item),
            backgroundColor: isDark
                ? AppColors.darkSurface
                : AppColors.lightSurface,
          );
        },
      ),
    );
  }
}

class QuantitySelector extends StatelessWidget {
  final int quantity;
  final ValueChanged<int> onChanged;
  final double size;

  const QuantitySelector({
    super.key,
    required this.quantity,
    required this.onChanged,
    this.size = 32,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _buildBtn(
            Icons.remove_rounded,
            quantity > 1 ? () => onChanged(quantity - 1) : null,
          ),
          SizedBox(
            width: size + 4,
            child: Center(
              child: Text(
                '$quantity',
                style: const TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                ),
              ),
            ),
          ),
          _buildBtn(
            Icons.add_rounded,
            () => onChanged(quantity + 1),
            isAdd: true,
          ),
        ],
      ),
    );
  }

  Widget _buildBtn(IconData icon, VoidCallback? onTap, {bool isAdd = false}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: size,
          height: size,
          child: Icon(
            icon,
            size: 18,
            color: onTap == null
                ? AppColors.lightTextSecondary
                : (isAdd ? AppColors.primary : AppColors.lightTextPrimary),
          ),
        ),
      ),
    );
  }
}

class MapControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onPressed;
  final Color? color;
  final Color? bgColor;
  final String? heroTag;

  const MapControlButton({
    super.key,
    required this.icon,
    required this.onPressed,
    this.color,
    this.bgColor,
    this.heroTag,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return FloatingActionButton(
      heroTag: heroTag,
      onPressed: onPressed,
      mini: true,
      backgroundColor: bgColor ?? (isDark ? AppColors.darkCard : Colors.white),
      foregroundColor: color ?? AppColors.primary,
      elevation: 3,
      child: Icon(icon, size: 20),
    );
  }
}

class RoleSelectorCard extends StatelessWidget {
  final String role;
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const RoleSelectorCard({
    super.key,
    required this.role,
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: isSelected
                ? AppColors.primary
                : (isDark ? AppColors.darkCard : Colors.white),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary
                  : (isDark ? AppColors.darkDivider : AppColors.lightDivider),
              width: isSelected ? 2 : 1.5,
            ),
            boxShadow: isSelected
                ? [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.3),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ]
                : null,
          ),
          child: Column(
            children: [
              Icon(
                icon,
                size: 28,
                color: isSelected
                    ? Colors.white
                    : (isDark
                          ? AppColors.darkTextPrimary
                          : AppColors.lightTextPrimary),
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontFamily: AppTheme.fontFamily,
                  fontWeight: FontWeight.w700,
                  fontSize: 13,
                  color: isSelected
                      ? Colors.white
                      : (isDark
                            ? AppColors.darkTextPrimary
                            : AppColors.lightTextPrimary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class BalanceHeaderCard extends StatelessWidget {
  final double balance;
  final String? subtitle;
  final List<Widget>? actions;

  const BalanceHeaderCard({
    super.key,
    required this.balance,
    this.subtitle,
    this.actions,
  });

  @override
  Widget build(BuildContext context) {
    return GradientCard(
      gradient: AppTheme.sunsetGradient(),
      padding: const EdgeInsets.fromLTRB(20, 22, 20, 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'الرصيد المتاح',
                      style: TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: Colors.white70,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${balance.toStringAsFixed(0)} ل.س',
                      style: const TextStyle(
                        fontFamily: AppTheme.fontFamily,
                        color: Colors.white,
                        fontSize: 26,
                        fontWeight: FontWeight.w800,
                        letterSpacing: -0.5,
                      ),
                    ),
                  ],
                ),
              ),
              if (actions != null) ...actions!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 14),
            Text(
              subtitle!,
              style: const TextStyle(
                fontFamily: AppTheme.fontFamily,
                color: Colors.white70,
                fontSize: 13,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class ButtonWithIcon extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool isLoading;
  final bool isOutlined;
  final Color? color;
  final double? width;

  const ButtonWithIcon({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    this.isLoading = false,
    this.isOutlined = false,
    this.color,
    this.width,
  });

  @override
  Widget build(BuildContext context) {
    final btnColor = color ?? AppColors.primary;
    if (isOutlined) {
      return SizedBox(
        width: width,
        child: OutlinedButton.icon(
          onPressed: isLoading ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: btnColor,
            side: BorderSide(color: btnColor, width: 1.5),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
            ),
          ),
          icon: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(btnColor),
                  ),
                )
              : Icon(icon, size: 18),
          label: Text(label),
        ),
      );
    }

    return SizedBox(
      width: width ?? double.infinity,
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: btnColor,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
        ),
        icon: isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Icon(icon, size: 18),
        label: Text(label),
      ),
    );
  }
}
