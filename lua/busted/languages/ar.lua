local s = require('say')

s:set_namespace('ar')

-- 'Pending: test.lua @ 12 \n description
s:set('output.pending', 'عالِق')
s:set('output.failure', 'فَشَل')
s:set('output.failure', 'نَجاح')

s:set('output.pending_plural', 'عالِق')
s:set('output.failure_plural', 'إخْفاقات')
s:set('output.success_plural', 'نَجاحات')

s:set('output.pending_zero', 'عالِق')
s:set('output.failure_zero', 'إخْفاقات')
s:set('output.success_zero', 'نَجاحات')

s:set('output.pending_single', 'عالِق')
s:set('output.failure_single', 'فَشَل')
s:set('output.success_single', 'نَجاح')

s:set('output.seconds', 'ثَوانٍ')

-- definitions following are not used within the 'say' namespace
return {
  failure_messages = {
    'فَشِلَت %d مِنْ الإِختِبارات',
    'فَشِلَت إخْتِباراتُك',
    'برمجيَّتُكَ ضَعيْفة، أنْصَحُكَ بالتَّقاعُد',
    'تقع برمجيَّتُكَ في مَنطِقَةِ الخَطَر',
    'أقترِحُ ألّا تَتَقَدَّم بالإختِبار، علَّ يبْقى الطابِقُ مَستوراَ',
    'جَدَّتي، فِي أَثْناءِ نَومِها، تَكتبُ بَرمَجياتٍ أفْضلُ مِن هذه',
    'يَوَدُّ ليْ مُساعَدَتُكْ، لَكِنّْ...'
  },
  success_messages = {
    'رائِع! تَمَّ إجْتِيازُ جَميعُ الإختِباراتِ بِنَجاحٍ',
    'قُل ما شِئت، لا أكتَرِث: busted شَهِدَ لي!',
    'حَقَّ عَليْكَ الإفتِخار',
    'نَجاحٌ مُبْهِر!',
    'عَليكَ بالإحتِفال؛ نَجَحَت جَميعُ التَجارُب'
  }
}
