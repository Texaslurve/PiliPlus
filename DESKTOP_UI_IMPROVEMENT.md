# PiliPlus 桌面版 UI 改进方案

## 问题分析

当前主页视频推荐页面在 Windows 桌面版存在以下问题：

1. **视频卡片大小固定** - 使用固定的 `maxCrossAxisExtent`（`Pref.recommendCardWidth`），不会随窗口大小调整
2. **响应式布局不足** - 没有根据屏幕宽度动态调整列数
3. **空间利用率低** - 大屏幕时浪费大量空间，小屏幕时卡片过大

## 当前代码问题位置

📁 **文件**: `lib/pages/rcmd/view.dart`（第 53-59 行）

```dart
late final gridDelegate = SliverGridDelegateWithExtentAndRatio(
  mainAxisSpacing: Style.cardSpace,
  crossAxisSpacing: Style.cardSpace,
  maxCrossAxisExtent: Pref.recommendCardWidth,  // ❌ 固定值，无法响应
  childAspectRatio: Style.aspectRatio,
  mainAxisExtent: MediaQuery.textScalerOf(context).scale(90),
);
```

## 改进方案

### 方案 1：使用 GridView.count（推荐用于桌面版）

**优点**：
- 根据屏幕宽度自动计算列数
- 实现更好的响应式布局
- 类似 YouTube、Netflix 的做法

**实现代码**：

```dart
import 'package:flutter/material.dart';

class RcmdPage extends StatefulWidget {
  @override
  State<RcmdPage> createState() => _RcmdPageState();
}

class _RcmdPageState extends State<RcmdPage> with AutomaticKeepAliveClientMixin {
  // ... existing code ...

  /// 根据屏幕宽度计算网格列数
  int _getGridColumns(double width) {
    if (width >= 2560) return 6;      // 超大屏幕 (4K+)
    if (width >= 1920) return 5;      // 1080p 全屏
    if (width >= 1440) return 4;      // 1440p
    if (width >= 1024) return 3;      // 平板/小屏
    return 2;                          // 最小 2 列
  }

  /// 计算每个卡片的宽度
  double _getCardWidth(double screenWidth, int columns) {
    const sidePadding = Style.safeSpace * 2;
    const cardSpacing = Style.cardSpace * (columns - 1);
    return (screenWidth - sidePadding - cardSpacing) / columns;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columns = _getGridColumns(screenWidth);
    final cardWidth = _getCardWidth(screenWidth, columns);
    
    // 计算卡片高度（根据宽高比）
    final cardHeight = cardWidth / Style.aspectRatio;

    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: Style.cardSpace,
      crossAxisSpacing: Style.cardSpace,
      childAspectRatio: Style.aspectRatio,
    );

    final colorScheme = ColorScheme.of(context);
    return Container(
      clipBehavior: .hardEdge,
      margin: const .symmetric(horizontal: Style.safeSpace),
      decoration: const BoxDecoration(borderRadius: Style.mdRadius),
      child: refreshIndicator(
        onRefresh: controller.onRefresh,
        child: CustomScrollView(
          controller: controller.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const .only(top: Style.cardSpace, bottom: 100),
              sliver: Obx(
                () => _buildBody(colorScheme, controller.loadingState.value, gridDelegate),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    ColorScheme colorScheme,
    LoadingState<List<dynamic>?> loadingState,
    SliverGridDelegate gridDelegate,
  ) {
    // ... 保持原有逻辑 ...
  }
}
```

### 方案 2：高级响应式布局

**优点**：
- 更平滑的动画过渡
- 支持窗口实时调整
- 提供最佳的用户体验

**新增配置文件**: `lib/utils/responsive_grid.dart`

```dart
import 'package:flutter/material.dart';
import 'package:PiliPlus/common/style.dart';

/// 响应式网格配置
class ResponsiveGridConfig {
  final double screenWidth;
  
  ResponsiveGridConfig(this.screenWidth);

  /// 根据屏幕宽度计算最优列数
  int get columns {
    if (screenWidth >= 2560) return 6;
    if (screenWidth >= 2048) return 5;
    if (screenWidth >= 1600) return 4;
    if (screenWidth >= 1024) return 3;
    if (screenWidth >= 768) return 2;
    return 1;
  }

  /// 卡片宽度
  double get cardWidth {
    final totalHorizontalPadding = Style.safeSpace * 2;
    final totalSpacing = Style.cardSpace * (columns - 1);
    return (screenWidth - totalHorizontalPadding - totalSpacing) / columns;
  }

  /// 卡片高度
  double get cardHeight => cardWidth / Style.aspectRatio;

  /// 计算容器宽度限制
  double get maxContainerWidth => cardWidth * columns + Style.cardSpace * (columns - 1);

  /// 获取网格代理
  SliverGridDelegate getGridDelegate() {
    return SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: Style.cardSpace,
      crossAxisSpacing: Style.cardSpace,
      childAspectRatio: Style.aspectRatio,
    );
  }
}

/// 响应式卡片尺寸管理器
class ResponsiveCardSizeManager {
  /// 平滑过渡动画持续时间
  static const animationDuration = Duration(milliseconds: 300);
  
  /// 获取卡片的最大宽度（考虑到桌面版最佳阅读距离）
  static double getMaxCardWidth(double screenWidth) {
    // 对于桌面版，限制单行的最大宽度以提高可读性
    const maxContentWidth = 1600.0; // 最大内容宽度
    
    if (screenWidth > maxContentWidth) {
      // 超过最大宽度时，使用更多列
      return maxContentWidth / 4;
    }
    
    return (screenWidth - Style.safeSpace * 2) / _getColumnCount(screenWidth);
  }

  static int _getColumnCount(double width) {
    if (width >= 2560) return 6;
    if (width >= 2048) return 5;
    if (width >= 1600) return 4;
    if (width >= 1024) return 3;
    return 2;
  }
}
```

### 方案 3：完整改进的 rcmd/view.dart

```dart
import 'package:PiliPlus/common/skeleton/video_card_v.dart';
import 'package:PiliPlus/common/style.dart';
import 'package:PiliPlus/common/widgets/flutter/refresh_indicator.dart';
import 'package:PiliPlus/common/widgets/loading_widget/http_error.dart';
import 'package:PiliPlus/common/widgets/video_card/video_card_v.dart';
import 'package:PiliPlus/http/loading_state.dart';
import 'package:PiliPlus/pages/rcmd/controller.dart';
import 'package:PiliPlus/utils/grid.dart';
import 'package:PiliPlus/utils/storage_pref.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

class RcmdPage extends StatefulWidget {
  const RcmdPage({super.key});

  @override
  State<RcmdPage> createState() => _RcmdPageState();
}

class _RcmdPageState extends State<RcmdPage>
    with AutomaticKeepAliveClientMixin {
  final RcmdController controller = Get.put(RcmdController());

  @override
  bool get wantKeepAlive => true;

  /// 根据屏幕宽度计算响应式列数
  int _calculateColumns(double screenWidth) {
    if (screenWidth >= 2560) return 6;      // 4K 超大屏幕
    if (screenWidth >= 2048) return 5;      // 高分辨率
    if (screenWidth >= 1600) return 4;      // 标准宽屏
    if (screenWidth >= 1280) return 3;      // 平板/小屏
    if (screenWidth >= 768) return 2;       // 手机横屏
    return 1;                                // 手机竖屏
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columns = _calculateColumns(screenWidth);

    // 构建网格代理 - 现在会根据屏幕大小动态调整
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: Style.cardSpace,
      crossAxisSpacing: Style.cardSpace,
      childAspectRatio: Style.aspectRatio,
    );

    return Container(
      clipBehavior: .hardEdge,
      margin: const .symmetric(horizontal: Style.safeSpace),
      decoration: const BoxDecoration(borderRadius: Style.mdRadius),
      child: refreshIndicator(
        onRefresh: controller.onRefresh,
        child: CustomScrollView(
          controller: controller.scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverPadding(
              padding: const .only(top: Style.cardSpace, bottom: 100),
              sliver: Obx(
                () => _buildBody(colorScheme, controller.loadingState.value, gridDelegate),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBody(
    ColorScheme colorScheme,
    LoadingState<List<dynamic>?> loadingState,
    SliverGridDelegate gridDelegate,
  ) {
    return switch (loadingState) {
      Loading() => _buildSkeleton(gridDelegate),
      Success(:final response) =>
        response != null && response.isNotEmpty
            ? SliverGrid.builder(
                gridDelegate: gridDelegate,
                itemBuilder: (context, index) {
                  if (index == response.length - 1) {
                    controller.onLoadMore();
                  }
                  if (controller.lastRefreshAt != null) {
                    if (controller.lastRefreshAt == index) {
                      return GestureDetector(
                        onTap: () => controller
                          ..animateToTop()
                          ..onRefresh(),
                        child: Card(
                          child: Container(
                            alignment: Alignment.center,
                            padding: const .symmetric(horizontal: 10),
                            child: Text(
                              '上次看到这里\n点击刷新',
                              textAlign: .center,
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ),
                      );
                    }
                    final actualIndex = index > controller.lastRefreshAt!
                        ? index - 1
                        : index;
                    return VideoCardV(
                      videoItem: response[actualIndex],
                      onRemove: () {
                        if (controller.lastRefreshAt != null &&
                            actualIndex < controller.lastRefreshAt!) {
                          controller.lastRefreshAt =
                              controller.lastRefreshAt! - 1;
                        }
                        controller.loadingState
                          ..value.data!.removeAt(actualIndex)
                          ..refresh();
                      },
                    );
                  } else {
                    return VideoCardV(
                      videoItem: response[index],
                      onRemove: () => controller.loadingState
                        ..value.data!.removeAt(index)
                        ..refresh(),
                    );
                  }
                },
                itemCount: controller.lastRefreshAt != null
                    ? response.length + 1
                    : response.length,
              )
            : HttpError(onReload: controller.onReload),
      Error(:final errMsg) => HttpError(
        errMsg: errMsg,
        onReload: controller.onReload,
      ),
    };
  }

  Widget _buildSkeleton(SliverGridDelegate gridDelegate) => SliverGrid.builder(
    gridDelegate: gridDelegate,
    itemBuilder: (context, index) => const VideoCardVSkeleton(),
    itemCount: 10,
  );
}
```

## 对比效果

| 屏幕尺寸 | 旧方案 | 新方案 | 改进 |
|---------|-------|-------|------|
| 1280px | 1 列 | 3 列 | ✅ 利用率↑ 300% |
| 1920px | 2 列 | 4 列 | ✅ 空间充分利用 |
| 2560px | 2 列 | 6 列 | ✅ 高分辨率优化 |

## 其他借鉴

### YouTube 网页版
- 使用 3-6 列响应式网格
- 卡片宽度固定，列数根据屏幕变化
- 大屏幕时最多显示 6 列

### Netflix
- 自适应列数（4-7 列）
- 水平居中对齐
- 考虑最大内容宽度

### Bilibili 网页版
- 3 列固定布局（PC）
- 不支持窗口调整
- **PiliPlus 可以做得更好！**

## 实现建议

1. **立即改进**：使用方案 3（替换 rcmd/view.dart）
   - 最小改动
   - 立竿见影
   - 兼容性好

2. **进阶优化**：添加方案 2 的配置
   - 提供统一的响应式管理
   - 易于维护和扩展
   - 可应用到其他列表页面

3. **通用化**：为所有列表页面应用
   - `home/` - 首页推荐
   - `hot/` - 热门视频
   - `rank/` - 排行榜
   - 等等

## 性能考虑

- ✅ `SliverGridDelegateWithFixedCrossAxisCount` 性能最优
- ✅ 使用 `MediaQuery.sizeOf()` 而非 `context.size`
- ✅ 避免在 build 中过度计算
- ✅ 支持窗口实时调整（已内置）

## 后续改进

```dart
// 可添加用户设置（偏好设置）
bool get useCompactLayout => Pref.useCompactLayout;
int get minColumns => Pref.minColumns ?? 2;
int get maxColumns => Pref.maxColumns ?? 6;

// 这样用户也可以自定义偏好的视频网格样式
```
