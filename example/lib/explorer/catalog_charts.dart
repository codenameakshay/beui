// Charts family catalog — sidebar order matches https://beui.dev/charts.
import '../demos/bump_chart_demo.dart';
import '../demos/sankey_chart_demo.dart';
import '../demos/candlestick_chart_demo.dart';
import '../demos/composition_chart_demo.dart';
import '../demos/donut_chart_demo.dart';
import '../demos/funnel_chart_demo.dart';
import '../demos/heat_calendar_demo.dart';
import '../demos/liquidity_heatmap_demo.dart';
import '../demos/order_book_demo.dart';
import '../demos/price_target_fan_demo.dart';
import '../demos/returns_calendar_demo.dart';
import '../demos/status_bar_demo.dart';
import '../demos/treemap_demo.dart';
import '../demos/volume_profile_demo.dart';
import 'catalog.dart';

/// Charts explorer entries in beui.dev sidebar order.
const List<ExploreEntry> kCharts = [
  ExploreEntry(
    title: 'Sankey Chart',
    slug: 'sankey-chart',
    section: ExploreSection.charts,
    isNew: true,
    blurb: 'Weighted flows between stages that draw in and morph with your data.',
    builder: sankeyChartDemo,
  ),
  ExploreEntry(
    title: 'Treemap',
    slug: 'treemap',
    section: ExploreSection.charts,
    isNew: true,
    blurb:
        'Proportional tiles that morph with your data, with value and share tooltips.',
    builder: treemapDemo,
  ),
  ExploreEntry(
    title: 'Candlestick Chart',
    slug: 'candlestick-chart',
    section: ExploreSection.charts,
    isNew: true,
    blurb:
        'OHLC candles with a live last price and volume, inspectable by keyboard.',
    builder: candlestickChartDemo,
  ),
  ExploreEntry(
    title: 'Donut Chart',
    slug: 'donut-chart',
    section: ExploreSection.charts,
    isNew: true,
    blurb: 'Round-capped ring with a live center, legend, and sweep-in motion.',
    builder: donutChartDemo,
  ),
  ExploreEntry(
    title: 'Volume Profile',
    slug: 'volume-profile',
    section: ExploreSection.charts,
    isNew: true,
    blurb: 'Horizontal volume-by-price with POC and a value-area highlight.',
    builder: volumeProfileDemo,
  ),
  ExploreEntry(
    title: 'Status Bar',
    slug: 'status-bar',
    section: ExploreSection.charts,
    isNew: true,
    blurb:
        'Proportional incident bar with operational, degraded, and outage segments.',
    builder: statusBarDemo,
  ),
  ExploreEntry(
    title: 'Composition Chart',
    slug: 'composition-chart',
    section: ExploreSection.charts,
    isNew: true,
    blurb: '100% stacked bar or area composition across periods.',
    builder: compositionChartDemo,
  ),
  ExploreEntry(
    title: 'Funnel Chart',
    slug: 'funnel-chart',
    section: ExploreSection.charts,
    isNew: true,
    blurb: 'Conversion funnel with curved morphs, drop-off, and stage buttons.',
    builder: funnelChartDemo,
  ),
  ExploreEntry(
    title: 'Liquidity Heatmap',
    slug: 'liquidity-heatmap',
    section: ExploreSection.charts,
    isNew: true,
    blurb: 'Order-book liquidity bands over time with a price trace.',
    builder: liquidityHeatmapDemo,
  ),
  ExploreEntry(
    title: 'Bump Chart',
    slug: 'bump-chart',
    section: ExploreSection.charts,
    isNew: true,
    blurb:
        'Ranking bump chart with curved series that break on missing periods.',
    builder: bumpChartDemo,
  ),
  ExploreEntry(
    title: 'Order Book',
    slug: 'order-book',
    section: ExploreSection.charts,
    isNew: true,
    blurb: 'Live bid/ask depth tables, spread, and a balance bar.',
    builder: orderBookDemo,
  ),
  ExploreEntry(
    title: 'Heat Calendar',
    slug: 'heat-calendar',
    section: ExploreSection.charts,
    isNew: true,
    blurb:
        'GitHub-style contribution heatmap with range selection and legend filter.',
    builder: heatCalendarDemo,
  ),
  ExploreEntry(
    title: 'Returns Calendar',
    slug: 'returns-calendar',
    section: ExploreSection.charts,
    isNew: true,
    blurb:
        'Monthly returns grid with gain/loss tint and compounded span totals.',
    builder: returnsCalendarDemo,
  ),
  ExploreEntry(
    title: 'Price Target Fan',
    slug: 'price-target-fan',
    section: ExploreSection.charts,
    isNew: true,
    blurb: 'High/mean/low price-target fan over a history path with a cursor.',
    builder: priceTargetFanDemo,
  ),
];
