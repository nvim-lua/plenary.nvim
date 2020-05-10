local s = require('say')

s:set_namespace('ja')

-- 'Pending: test.lua @ 12 \n description
s:set('output.pending', '保留')
s:set('output.failure', '失敗')
s:set('output.success', '成功')

s:set('output.pending_plural', '保留')
s:set('output.failure_plural', '失敗')
s:set('output.success_plural', '成功')

s:set('output.pending_zero', '保留')
s:set('output.failure_zero', '失敗')
s:set('output.success_zero', '成功')

s:set('output.pending_single', '保留')
s:set('output.failure_single', '失敗')
s:set('output.success_single', '成功')

s:set('output.seconds', '秒')

-- definitions following are not used within the 'say' namespace
return {
  failure_messages = {
    '%d個の仕様が破綻しています',
    '仕様が破綻しています',
    'あなたの書くコードは良くないので反省するべきです',
    'あなたの書くコードは危険地帯にあります',
    'おかしなゲームです。勝利する唯一の方法はテストをしないことです',
    '私の祖母でもPentium Pentium III x86の上でもっといいコードを書いていましたよ',
    'いつも失敗しているのでビールでも飲みましょう',
    '罪悪感を持ちましょう',
  },
  success_messages = {
    'オォーイェー、テストが通った',
    '問題ない、テストがある',
    '順調ですね',
    '大成功',
    'テストが通ったし、ビールでも飲もう',
  }
}
