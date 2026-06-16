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

  /// 根据屏幕宽度计算响应式列数 (借鉴 YouTube/Netflix 的做法)
  /// 
  /// 屏幕断点:
  /// - >= 2560px: 6 列 (4K 超大屏幕)
  /// - >= 2048px: 5 列 (高分辨率)
  /// - >= 1600px: 4 列 (标准宽屏)
  /// - >= 1280px: 3 列 (平板/小屏)
  /// - >= 768px:  2 列 (手机横屏)
  /// - < 768px:   1 列 (手机竖屏)
  int _calculateColumns(double screenWidth) {
    if (screenWidth >= 2560) return 6;
    if (screenWidth >= 2048) return 5;
    if (screenWidth >= 1600) return 4;
    if (screenWidth >= 1280) return 3;
    if (screenWidth >= 768) return 2;
    return 1;
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colorScheme = ColorScheme.of(context);
    
    // 获取屏幕宽度并计算列数
    final screenWidth = MediaQuery.sizeOf(context).width;
    final columns = _calculateColumns(screenWidth);

    // 创建响应式网格代理 (替换原来的固定宽度方式)
    final gridDelegate = SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: columns,
      mainAxisSpacing: Style.cardSpace,
      crossAxisSpacing: Style.cardSpace,
      childAspectRatio: Style.aspectRatio,
      // 可选: 设置最小高度以匹配原有布局
      // mainAxisExtent: MediaQuery.textScalerOf(context).scale(90),
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
