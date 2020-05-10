local s = require('say')

s:set_namespace('th')

-- 'Pending: test.lua @ 12 \n description
s:set('output.pending', 'อยู่ระหว่างดำเนินการ')
s:set('output.failure', 'ล้มเหลว')
s:set('output.success', 'สำเร็จ')

s:set('output.pending_plural', 'อยู่ระหว่างดำเนินการ')
s:set('output.failure_plural', 'ล้มเหลว')
s:set('output.success_plural', 'สำเร็จ')

s:set('output.pending_zero', 'อยู่ระหว่างดำเนินการ')
s:set('output.failure_zero', 'ล้มเหลว')
s:set('output.success_zero', 'สำเร็จ')

s:set('output.pending_single', 'อยู่ระหว่างดำเนินการ')
s:set('output.failure_single', 'ล้มเหลว')
s:set('output.success_single', 'สำเร็จ')

s:set('output.seconds', 'วินาที')

-- definitions following are not used within the 'say' namespace
return {
  failure_messages = {
    'คุณมี %d บัสเต็ดสเปค',
    'สเปคของคุณคือ บัสเต็ด',
    'โค้ดของคุณไม่ดีเลย คุณควรรู้สึกแย่น่ะ',
    'โค้ดของคุณอยู่ในเขตอันตราย!',
    'มันแปลกๆน่ะ วิธีที่จะชนะไม่ได้มีแค่เทสอย่างเดียว',
    'ยายผมเขียนสเปคดีกว่านี้อีก บนเครื่อง 386',
    'ทุกๆครั้งที่ล้มเหลว, ดื่มเบียร์แก้วใหม่',
    'แย่จัง นายท่าน'
  },
  success_messages = {
    'อุ๊ตะ!!!, สเปคผ่าน!',
    'ไม่สำคัญ, มีสเปค',
    'ฟินเลยดิ นายท่าน',
    'สำเร็จ ยอดเยี่ยม',
    'เทสผ่าน, ดื่มเบียร์ๆๆๆ',
  }
}
