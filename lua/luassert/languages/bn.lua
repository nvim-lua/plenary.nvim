local s = require('say')

s:set_namespace('bn') -- bn = Bangla/Bengali

s:set("assertion.same.positive", "অবজেক্টগুলো একই হওয়ার কথা ছিল।\nপ্রাপ্ত:\n%s\nপ্রত্যাশিত:\n%s")
s:set("assertion.same.negative", "অবজেক্টগুলো একই না হওয়ার কথা ছিল।\nপ্রাপ্ত:\n%s\nঅপ্রত্যাশিত:\n%s")

s:set("assertion.equals.positive", "অবজেক্টগুলো সমান হওয়ার কথা ছিল।\nপ্রাপ্ত:\n%s\nপ্রত্যাশিত:\n%s")
s:set("assertion.equals.negative", "অবজেক্টগুলো সমান না হওয়ার কথা ছিল।\nপ্রাপ্ত:\n%s\nঅপ্রত্যাশিত:\n%s")

s:set("assertion.near.positive", "মানগুলো কাছাকাছি হওয়ার কথা ছিল।\nপ্রাপ্ত:\n%s\nপ্রত্যাশিত:\n%s ± %s")
s:set("assertion.near.negative", "মানগুলো কাছাকাছি না হওয়ার কথা ছিল।\nপ্রাপ্ত:\n%s\nঅপ্রত্যাশিত:\n%s ± %s")

s:set("assertion.matches.positive", "স্ট্রিংগুলো মেলানোর কথা ছিল।\nপ্রাপ্ত:\n%s\nপ্রত্যাশিত:\n%s")
s:set("assertion.matches.negative", "স্ট্রিংগুলো না মেলানোর কথা ছিল।\nপ্রাপ্ত:\n%s\nঅপ্রত্যাশিত:\n%s")

s:set("assertion.unique.positive", "অবজেক্টটি ইউনিক হওয়ার কথা ছিল:\n%s")
s:set("assertion.unique.negative", "অবজেক্টটি ইউনিক না হওয়ার কথা ছিল:\n%s")

s:set("assertion.error.positive", "ভিন্ন একটি ত্রুটি (error) প্রত্যাশিত ছিল।\nধরা পড়েছে:\n%s\nপ্রত্যাশিত:\n%s")
s:set("assertion.error.negative", "কোনো ত্রুটি (error) প্রত্যাশিত ছিল না, কিন্তু ধরা পড়েছে:\n%s")

s:set("assertion.truthy.positive", "সত্য (truthy) হওয়ার কথা ছিল, কিন্তু মান ছিল:\n%s")
s:set("assertion.truthy.negative", "সত্য (truthy) না হওয়ার কথা ছিল, কিন্তু মান ছিল:\n%s")

s:set("assertion.falsy.positive", "মিথ্যা (falsy) হওয়ার কথা ছিল, কিন্তু মান ছিল:\n%s")
s:set("assertion.falsy.negative", "মিথ্যা (falsy) না হওয়ার কথা ছিল, কিন্তু মান ছিল:\n%s")

s:set("assertion.called.positive", "%s বার কল হওয়ার কথা ছিল, কিন্তু হয়েছে %s বার।")
s:set("assertion.called.negative", "ঠিক %s বার কল হওয়া উচিত ছিল না, কিন্তু হয়েছে।")

s:set("assertion.called_at_least.positive", "কমপক্ষে %s বার কল হওয়ার কথা ছিল, কিন্তু হয়েছে %s বার।")
s:set("assertion.called_at_most.positive", "সর্বাধিক %s বার কল হওয়ার কথা ছিল, কিন্তু হয়েছে %s বার।")
s:set("assertion.called_more_than.positive", "%s বার এর চেয়ে বেশি কল হওয়ার কথা ছিল, কিন্তু হয়েছে %s বার।")
s:set("assertion.called_less_than.positive", "%s বার এর চেয়ে কম কল হওয়ার কথা ছিল, কিন্তু হয়েছে %s বার।")

s:set("assertion.called_with.positive", "ফাংশনটি কখনোই মিল থাকা আর্গুমেন্ট দিয়ে কল হয়নি।\nশেষবার কল (যদি থাকে):\n%s\nপ্রত্যাশিত:\n%s")
s:set("assertion.called_with.negative", "ফাংশনটি অন্তত একবার মিল থাকা আর্গুমেন্ট দিয়ে কল হয়েছে।\nশেষবার কল (মিলে গেলে):\n%s\nঅপ্রত্যাশিত:\n%s")

s:set("assertion.returned_with.positive", "ফাংশনটি কখনোই মিল থাকা মান ফেরত দেয়নি।\nশেষবার ফেরত (যদি থাকে):\n%s\nপ্রত্যাশিত:\n%s")
s:set("assertion.returned_with.negative", "ফাংশনটি অন্তত একবার মিল থাকা মান ফেরত দিয়েছে।\nশেষবার ফেরত (মিলে গেলে):\n%s\nঅপ্রত্যাশিত:\n%s")

s:set("assertion.returned_arguments.positive", "%sটি আর্গুমেন্ট দিয়ে কল হওয়ার কথা ছিল, কিন্তু হয়েছে %sটি দিয়ে।")
s:set("assertion.returned_arguments.negative", "%sটি আর্গুমেন্ট দিয়ে কল হওয়া উচিত ছিল না, কিন্তু হয়েছে %sটি দিয়ে।")

-- errors
s:set("assertion.internal.argtolittle", "'%s' ফাংশনের জন্য কমপক্ষে %sটি আর্গুমেন্ট দরকার, কিন্তু পাওয়া গেছে: %s")
s:set("assertion.internal.badargtype", "'%s' ফাংশনের %s নম্বর আর্গুমেন্ট ভুল (%s প্রত্যাশিত, কিন্তু %s পাওয়া গেছে)")
