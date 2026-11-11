import 'dart:math';

/// The result of uncovering one tile in a Mines round.
enum BeuiMinesTile {
  /// A safe tile that increases the payout multiplier.
  gem,

  /// A losing tile that ends the round.
  mine,
}

/// Lifecycle of a Mines round.
enum BeuiMinesPhase {
  /// No board has been started or the previous board was cleared.
  idle,

  /// A board is active and accepts unrevealed picks.
  playing,

  /// A mine was revealed.
  busted,

  /// The player cashed out or found every safe tile.
  cashed,
}

/// A deterministic, UI-independent Mines round.
///
/// The widget supplies a fresh [Random] only when a round starts. Tests can
/// supply a seeded generator without adding randomness controls to the widget
/// API.
class MinesRound {
  MinesRound({required this.size, required this.mineCount})
    : assert(size >= 2),
      assert(mineCount >= 1 && mineCount < size * size);

  /// Number of tiles on each side of the board.
  final int size;

  /// Number of mines fixed for this round.
  final int mineCount;

  final Set<int> _mines = <int>{};
  final List<int> _picked = <int>[];

  /// Current round phase.
  BeuiMinesPhase phase = BeuiMinesPhase.idle;

  /// Total number of board tiles.
  int get tileCount => size * size;

  /// Number of safe tiles already revealed.
  int get gemsFound => _picked.where((tile) => !_mines.contains(tile)).length;

  /// Immutable pick order for the current round.
  List<int> get picked => List<int>.unmodifiable(_picked);

  /// Immutable mine positions for the current round.
  Set<int> get mines => Set<int>.unmodifiable(_mines);

  /// Current multiplier for the number of gems found.
  double get multiplier => beuiMinesMultiplier(tileCount, mineCount, gemsFound);

  /// Places a new board. The board stays fixed until [start] is called again.
  void start(Random random) {
    final order = List<int>.generate(tileCount, (index) => index);
    for (var index = order.length - 1; index > 0; index--) {
      final swap = random.nextInt(index + 1);
      final value = order[index];
      order[index] = order[swap];
      order[swap] = value;
    }
    _mines
      ..clear()
      ..addAll(order.take(mineCount));
    _picked.clear();
    phase = BeuiMinesPhase.playing;
  }

  /// Reveals [tile], ignoring invalid, duplicate, or out-of-round actions.
  MinesReveal? reveal(int tile) {
    if (phase != BeuiMinesPhase.playing ||
        tile < 0 ||
        tile >= tileCount ||
        _picked.contains(tile)) {
      return null;
    }

    _picked.add(tile);
    if (_mines.contains(tile)) {
      phase = BeuiMinesPhase.busted;
      return MinesReveal(
        tile: tile,
        result: BeuiMinesTile.mine,
        multiplier: 0,
        gems: gemsFound,
        completedRound: true,
      );
    }

    final complete = gemsFound == tileCount - mineCount;
    if (complete) phase = BeuiMinesPhase.cashed;
    return MinesReveal(
      tile: tile,
      result: BeuiMinesTile.gem,
      multiplier: multiplier,
      gems: gemsFound,
      completedRound: complete,
    );
  }

  /// Ends a live round after at least one gem has been found.
  MinesCashOut? cashOut() {
    if (phase != BeuiMinesPhase.playing || gemsFound == 0) return null;
    phase = BeuiMinesPhase.cashed;
    return MinesCashOut(multiplier: multiplier, gems: gemsFound);
  }
}

/// Observable result from [MinesRound.reveal].
class MinesReveal {
  const MinesReveal({
    required this.tile,
    required this.result,
    required this.multiplier,
    required this.gems,
    required this.completedRound,
  });

  /// Tile index reported by the reveal.
  final int tile;

  /// Whether the revealed tile was a gem or mine.
  final BeuiMinesTile result;

  /// Payout multiplier after the reveal, or zero for a mine.
  final double multiplier;

  /// Number of safe tiles found before the round ended.
  final int gems;

  /// Whether this reveal ended the round.
  final bool completedRound;
}

/// Observable result from [MinesRound.cashOut].
class MinesCashOut {
  const MinesCashOut({required this.multiplier, required this.gems});

  /// Final multiplier at cash-out.
  final double multiplier;

  /// Number of gems included in the payout.
  final int gems;
}

/// Returns the fair multiplier after [gems] safe picks from [tiles] with
/// [mines] mines. Inputs are rounded and bounded to valid board counts.
double beuiMinesMultiplier(int tiles, int mines, int gems) {
  if (tiles < 1) return 1;
  final safeMines = mines.round().clamp(0, tiles - 1).toInt();
  final safeGems = gems.round().clamp(0, tiles - safeMines).toInt();
  var multiplier = 1.0;
  for (var index = 0; index < safeGems; index++) {
    multiplier *= (tiles - index) / (tiles - safeMines - index);
  }
  return multiplier;
}
