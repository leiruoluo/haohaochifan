/// 激励 slogan 库：内置自律风（减脂/健身向）+ 用户自定义
library;

import '../models/profile.dart';
import 'settlement.dart';

/// 内置 slogan（按场景分类）
const Map<String, List<String>> kSloganPool = {
  'achieved': [
    '今天的你，比昨天更靠近目标。',
    '自律即自由，缺口即勋章。',
    '好好吃饭，好好训练，好好生活。',
    '每一口自律，都是给未来的投资。',
    '达标打卡成功，坚持就是胜利！',
    '控制是自由的高级形式。',
    '今天也稳稳拿下了！',
  ],
  'close': [
    '只差一点点，明天再推一把。',
    '目标就在眼前，别松劲。',
    '90% 的完成度，也是进步。',
    '稳住，我们能赢。',
  ],
  'over': [
    '今天吃多了点，没关系，明天回归正轨。',
    '一顿吃不成胖子，一顿也饿不出腹肌。',
    '放轻松，允许自己偶尔松懈。',
    '记录本身就是一种进步。',
  ],
  'under': [
    '吃得太少反而伤代谢，记得补充营养。',
    '别饿着自己，好好吃饭才是长久之计。',
    '热量缺口过大了，明天多吃一点。',
  ],
  'empty': [
    '今天还没记录，记得回来打卡哦。',
    '记录每一天，才能掌控每一天。',
    '再忙，也别忘了好好吃饭。',
  ],
  'water': [
    '多喝水，代谢更好。',
    '水是减脂路上的隐形帮手。',
    '喝够水，皮肤和身材都会感谢你。',
  ],
};

/// 根据当日结算状态挑选 slogan
/// 优先用户自定义 slogan；未设置时从场景池中轮换
String pickSlogan({
  required UserProfile profile,
  required DaySettlement s,
  required int dayOfYear,
}) {
  if (profile.slogan.trim().isNotEmpty) return profile.slogan.trim();

  String scene;
  if (!s.hasData) {
    scene = 'empty';
  } else if (s.achieved) {
    scene = 'achieved';
  } else if (s.gapFromIdeal > 0 && s.gapFromIdeal <= 200) {
    scene = 'close';
  } else if (s.gapFromIdeal > 200) {
    scene = 'over';
  } else if (s.gapFromIdeal < -200) {
    scene = 'under';
  } else {
    scene = 'close';
  }
  if (!s.waterAchieved && s.hasData) scene = 'water';

  final pool = kSloganPool[scene] ?? kSloganPool['empty']!;
  return pool[dayOfYear % pool.length];
}
