import 'package:flutter/material.dart';

/// 设备类型
enum DeviceType {
  mobile,
  tablet,
  desktop,
}

/// 响应式布局工具
class ResponsiveLayout {
  /// 移动端最大宽度
  static const double mobileMaxWidth = 600;
  
  /// 平板最大宽度
  static const double tabletMaxWidth = 1200;
  
  /// 获取设备类型
  static DeviceType getDeviceType(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width < mobileMaxWidth) {
      return DeviceType.mobile;
    } else if (width < tabletMaxWidth) {
      return DeviceType.tablet;
    } else {
      return DeviceType.desktop;
    }
  }
  
  /// 是否是移动端
  static bool isMobile(BuildContext context) {
    return getDeviceType(context) == DeviceType.mobile;
  }
  
  /// 是否是平板
  static bool isTablet(BuildContext context) {
    return getDeviceType(context) == DeviceType.tablet;
  }
  
  /// 是否是桌面端
  static bool isDesktop(BuildContext context) {
    return getDeviceType(context) == DeviceType.desktop;
  }
  
  /// 获取内容最大宽度
  static double getContentMaxWidth(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return double.infinity;
      case DeviceType.tablet:
        return 800;
      case DeviceType.desktop:
        return 1000;
    }
  }
  
  /// 获取网格列数
  static int getGridColumns(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return 1;
      case DeviceType.tablet:
        return 2;
      case DeviceType.desktop:
        return 3;
    }
  }
  
  /// 获取内边距
  static EdgeInsets getContentPadding(BuildContext context) {
    final deviceType = getDeviceType(context);
    switch (deviceType) {
      case DeviceType.mobile:
        return const EdgeInsets.all(16);
      case DeviceType.tablet:
        return const EdgeInsets.all(24);
      case DeviceType.desktop:
        return const EdgeInsets.all(32);
    }
  }
}

/// 响应式布局构建器
class ResponsiveBuilder extends StatelessWidget {
  final Widget Function(BuildContext context, DeviceType deviceType) builder;
  
  const ResponsiveBuilder({
    super.key,
    required this.builder,
  });

  @override
  Widget build(BuildContext context) {
    return builder(context, ResponsiveLayout.getDeviceType(context));
  }
}

/// 响应式布局 Widget
/// 根据设备类型显示不同的 Widget
class ResponsiveWidget extends StatelessWidget {
  final Widget mobile;
  final Widget? tablet;
  final Widget? desktop;
  
  const ResponsiveWidget({
    super.key,
    required this.mobile,
    this.tablet,
    this.desktop,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveLayout.getDeviceType(context);
    
    switch (deviceType) {
      case DeviceType.mobile:
        return mobile;
      case DeviceType.tablet:
        return tablet ?? mobile;
      case DeviceType.desktop:
        return desktop ?? tablet ?? mobile;
    }
  }
}

/// 居中内容容器
/// 在大屏幕上限制内容最大宽度
class CenteredContent extends StatelessWidget {
  final Widget child;
  final double? maxWidth;
  final EdgeInsetsGeometry? padding;
  
  const CenteredContent({
    super.key,
    required this.child,
    this.maxWidth,
    this.padding,
  });

  @override
  Widget build(BuildContext context) {
    final contentMaxWidth = maxWidth ?? ResponsiveLayout.getContentMaxWidth(context);
    final contentPadding = padding ?? ResponsiveLayout.getContentPadding(context);
    
    return Center(
      child: Container(
        constraints: BoxConstraints(maxWidth: contentMaxWidth),
        padding: contentPadding,
        child: child,
      ),
    );
  }
}

/// 自适应网格布局
class AdaptiveGrid extends StatelessWidget {
  final List<Widget> children;
  final double spacing;
  final double runSpacing;
  final int? columns;
  
  const AdaptiveGrid({
    super.key,
    required this.children,
    this.spacing = 16,
    this.runSpacing = 16,
    this.columns,
  });

  @override
  Widget build(BuildContext context) {
    final columnCount = columns ?? ResponsiveLayout.getGridColumns(context);
    
    return LayoutBuilder(
      builder: (context, constraints) {
        final availableWidth = constraints.maxWidth - (spacing * (columnCount - 1));
        final itemWidth = availableWidth / columnCount;
        
        return Wrap(
          spacing: spacing,
          runSpacing: runSpacing,
          children: children.map((child) {
            return SizedBox(
              width: itemWidth,
              child: child,
            );
          }).toList(),
        );
      },
    );
  }
}

/// 自适应侧边栏布局
class AdaptiveSidebarLayout extends StatelessWidget {
  final Widget sidebar;
  final Widget content;
  final double sidebarWidth;
  final bool showSidebar;
  
  const AdaptiveSidebarLayout({
    super.key,
    required this.sidebar,
    required this.content,
    this.sidebarWidth = 300,
    this.showSidebar = true,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveLayout.getDeviceType(context);
    
    if (deviceType == DeviceType.mobile) {
      // 移动端：只显示内容，侧边栏通过 Drawer 访问
      return content;
    }
    
    // 平板/桌面端：显示侧边栏
    if (!showSidebar) {
      return content;
    }
    
    return Row(
      children: [
        SizedBox(
          width: sidebarWidth,
          child: sidebar,
        ),
        const VerticalDivider(width: 1),
        Expanded(child: content),
      ],
    );
  }
}

/// 分栏布局（主从布局）
class MasterDetailLayout extends StatelessWidget {
  final Widget master;
  final Widget? detail;
  final Widget? emptyDetail;
  final double masterWidth;
  
  const MasterDetailLayout({
    super.key,
    required this.master,
    this.detail,
    this.emptyDetail,
    this.masterWidth = 350,
  });

  @override
  Widget build(BuildContext context) {
    final deviceType = ResponsiveLayout.getDeviceType(context);
    
    if (deviceType == DeviceType.mobile) {
      // 移动端：只显示 master 或 detail
      return detail ?? master;
    }
    
    // 平板/桌面端：分栏显示
    return Row(
      children: [
        SizedBox(
          width: masterWidth,
          child: master,
        ),
        const VerticalDivider(width: 1),
        Expanded(
          child: detail ?? emptyDetail ?? _buildEmptyDetail(context),
        ),
      ],
    );
  }
  
  Widget _buildEmptyDetail(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.touch_app,
            size: 64,
            color: theme.colorScheme.primary.withOpacity(0.3),
          ),
          const SizedBox(height: 16),
          Text(
            '选择一项查看详情',
            style: theme.textTheme.bodyLarge?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// 屏幕尺寸扩展
extension ScreenSizeExtension on BuildContext {
  /// 屏幕宽度
  double get screenWidth => MediaQuery.of(this).size.width;
  
  /// 屏幕高度
  double get screenHeight => MediaQuery.of(this).size.height;
  
  /// 设备类型
  DeviceType get deviceType => ResponsiveLayout.getDeviceType(this);
  
  /// 是否是移动端
  bool get isMobile => ResponsiveLayout.isMobile(this);
  
  /// 是否是平板
  bool get isTablet => ResponsiveLayout.isTablet(this);
  
  /// 是否是桌面端
  bool get isDesktop => ResponsiveLayout.isDesktop(this);
  
  /// 是否是横屏
  bool get isLandscape => MediaQuery.of(this).orientation == Orientation.landscape;
  
  /// 是否是竖屏
  bool get isPortrait => MediaQuery.of(this).orientation == Orientation.portrait;
}
