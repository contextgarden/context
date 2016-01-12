if not modules then modules = { } end modules ['char-map'] = {
    version   = 1.001,
    comment   = "companion to char-ini.mkiv",
    author    = "Hans Hagen & Arthur Reutenauer",
    copyright = "PRAGMA ADE / ConTeXt Development Team",
    license   = "see context related readme files",
    dataonly  = true,
}

-- not yet used

characters = characters or { }

characters.casemap={
 [0x0049]={
  ["az"]={
   ["not_before_dot"]={
    ["lower"]={ 0x0131 },
    ["title"]={ 0x0049 },
    ["upper"]={ 0x0049 },
   },
  },
  ["lt"]={
   ["more_above"]={
    ["lower"]={ 0x0069, 0x0307 },
    ["title"]={ 0x0049 },
    ["upper"]={ 0x0049 },
   },
  },
  ["tr"]={
   ["not_before_dot"]={
    ["lower"]={ 0x0131 },
    ["title"]={ 0x0049 },
    ["upper"]={ 0x0049 },
   },
  },
 },
 [0x004A]={
  ["lt"]={
   ["more_above"]={
    ["lower"]={ 0x006A, 0x0307 },
    ["title"]={ 0x004A },
    ["upper"]={ 0x004A },
   },
  },
 },
 [0x0069]={
  ["az"]={
   ["all"]={
    ["lower"]={ 0x0069 },
    ["title"]={ 0x0130 },
    ["upper"]={ 0x0130 },
   },
  },
  ["tr"]={
   ["all"]={
    ["lower"]={ 0x0069 },
    ["title"]={ 0x0130 },
    ["upper"]={ 0x0130 },
   },
  },
 },
 [0x00CC]={
  ["lt"]={
   ["all"]={
    ["lower"]={ 0x0069, 0x0307, 0x0300 },
    ["title"]={ 0x00CC },
    ["upper"]={ 0x00CC },
   },
  },
 },
 [0x00CD]={
  ["lt"]={
   ["all"]={
    ["lower"]={ 0x0069, 0x0307, 0x0301 },
    ["title"]={ 0x00CD },
    ["upper"]={ 0x00CD },
   },
  },
 },
 [0x00DF]={
  [""]={
   ["all"]={
    ["lower"]={ 0x00DF },
    ["title"]={ 0x0053, 0x0073 },
    ["upper"]={ 0x0053, 0x0053 },
   },
  },
 },
 [0x0128]={
  ["lt"]={
   ["all"]={
    ["lower"]={ 0x0069, 0x0307, 0x0303 },
    ["title"]={ 0x0128 },
    ["upper"]={ 0x0128 },
   },
  },
 },
 [0x012E]={
  ["lt"]={
   ["more_above"]={
    ["lower"]={ 0x012F, 0x0307 },
    ["title"]={ 0x012E },
    ["upper"]={ 0x012E },
   },
  },
 },
 [0x0130]={
  [""]={
   ["all"]={
    ["lower"]={ 0x0069, 0x0307 },
    ["title"]={ 0x0130 },
    ["upper"]={ 0x0130 },
   },
  },
  ["az"]={
   ["all"]={
    ["lower"]={ 0x0069 },
    ["title"]={ 0x0130 },
    ["upper"]={ 0x0130 },
   },
  },
  ["tr"]={
   ["all"]={
    ["lower"]={ 0x0069 },
    ["title"]={ 0x0130 },
    ["upper"]={ 0x0130 },
   },
  },
 },
 [0x0149]={
  [""]={
   ["all"]={
    ["lower"]={ 0x0149 },
    ["title"]={ 0x02BC, 0x004E },
    ["upper"]={ 0x02BC, 0x004E },
   },
  },
 },
 [0x01F0]={
  [""]={
   ["all"]={
    ["lower"]={ 0x01F0 },
    ["title"]={ 0x004A, 0x030C },
    ["upper"]={ 0x004A, 0x030C },
   },
  },
 },
 [0x0307]={
  ["az"]={
   ["after_i"]={
    ["lower"]={},
    ["title"]={ 0x0307 },
    ["upper"]={ 0x0307 },
   },
  },
  ["lt"]={
   ["after_soft_dotted"]={
    ["lower"]={ 0x0307 },
    ["title"]={},
    ["upper"]={},
   },
  },
  ["tr"]={
   ["after_i"]={
    ["lower"]={},
    ["title"]={ 0x0307 },
    ["upper"]={ 0x0307 },
   },
  },
 },
 [0x0390]={
  [""]={
   ["all"]={
    ["lower"]={ 0x0390 },
    ["title"]={ 0x0399, 0x0308, 0x0301 },
    ["upper"]={ 0x0399, 0x0308, 0x0301 },
   },
  },
 },
 [0x03A3]={
  ["final_sigma"]={
   ["all"]={
    ["lower"]={ 0x03C2 },
    ["title"]={ 0x03A3 },
    ["upper"]={ 0x03A3 },
   },
  },
 },
 [0x03B0]={
  [""]={
   ["all"]={
    ["lower"]={ 0x03B0 },
    ["title"]={ 0x03A5, 0x0308, 0x0301 },
    ["upper"]={ 0x03A5, 0x0308, 0x0301 },
   },
  },
 },
 [0x0587]={
  [""]={
   ["all"]={
    ["lower"]={ 0x0587 },
    ["title"]={ 0x0535, 0x0582 },
    ["upper"]={ 0x0535, 0x0552 },
   },
  },
 },
 [0x1E96]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1E96 },
    ["title"]={ 0x0048, 0x0331 },
    ["upper"]={ 0x0048, 0x0331 },
   },
  },
 },
 [0x1E97]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1E97 },
    ["title"]={ 0x0054, 0x0308 },
    ["upper"]={ 0x0054, 0x0308 },
   },
  },
 },
 [0x1E98]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1E98 },
    ["title"]={ 0x0057, 0x030A },
    ["upper"]={ 0x0057, 0x030A },
   },
  },
 },
 [0x1E99]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1E99 },
    ["title"]={ 0x0059, 0x030A },
    ["upper"]={ 0x0059, 0x030A },
   },
  },
 },
 [0x1E9A]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1E9A },
    ["title"]={ 0x0041, 0x02BE },
    ["upper"]={ 0x0041, 0x02BE },
   },
  },
 },
 [0x1F50]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F50 },
    ["title"]={ 0x03A5, 0x0313 },
    ["upper"]={ 0x03A5, 0x0313 },
   },
  },
 },
 [0x1F52]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F52 },
    ["title"]={ 0x03A5, 0x0313, 0x0300 },
    ["upper"]={ 0x03A5, 0x0313, 0x0300 },
   },
  },
 },
 [0x1F54]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F54 },
    ["title"]={ 0x03A5, 0x0313, 0x0301 },
    ["upper"]={ 0x03A5, 0x0313, 0x0301 },
   },
  },
 },
 [0x1F56]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F56 },
    ["title"]={ 0x03A5, 0x0313, 0x0342 },
    ["upper"]={ 0x03A5, 0x0313, 0x0342 },
   },
  },
 },
 [0x1F80]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F80 },
    ["title"]={ 0x1F88 },
    ["upper"]={ 0x1F08, 0x0399 },
   },
  },
 },
 [0x1F81]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F81 },
    ["title"]={ 0x1F89 },
    ["upper"]={ 0x1F09, 0x0399 },
   },
  },
 },
 [0x1F82]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F82 },
    ["title"]={ 0x1F8A },
    ["upper"]={ 0x1F0A, 0x0399 },
   },
  },
 },
 [0x1F83]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F83 },
    ["title"]={ 0x1F8B },
    ["upper"]={ 0x1F0B, 0x0399 },
   },
  },
 },
 [0x1F84]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F84 },
    ["title"]={ 0x1F8C },
    ["upper"]={ 0x1F0C, 0x0399 },
   },
  },
 },
 [0x1F85]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F85 },
    ["title"]={ 0x1F8D },
    ["upper"]={ 0x1F0D, 0x0399 },
   },
  },
 },
 [0x1F86]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F86 },
    ["title"]={ 0x1F8E },
    ["upper"]={ 0x1F0E, 0x0399 },
   },
  },
 },
 [0x1F87]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F87 },
    ["title"]={ 0x1F8F },
    ["upper"]={ 0x1F0F, 0x0399 },
   },
  },
 },
 [0x1F88]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F80 },
    ["title"]={ 0x1F88 },
    ["upper"]={ 0x1F08, 0x0399 },
   },
  },
 },
 [0x1F89]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F81 },
    ["title"]={ 0x1F89 },
    ["upper"]={ 0x1F09, 0x0399 },
   },
  },
 },
 [0x1F8A]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F82 },
    ["title"]={ 0x1F8A },
    ["upper"]={ 0x1F0A, 0x0399 },
   },
  },
 },
 [0x1F8B]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F83 },
    ["title"]={ 0x1F8B },
    ["upper"]={ 0x1F0B, 0x0399 },
   },
  },
 },
 [0x1F8C]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F84 },
    ["title"]={ 0x1F8C },
    ["upper"]={ 0x1F0C, 0x0399 },
   },
  },
 },
 [0x1F8D]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F85 },
    ["title"]={ 0x1F8D },
    ["upper"]={ 0x1F0D, 0x0399 },
   },
  },
 },
 [0x1F8E]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F86 },
    ["title"]={ 0x1F8E },
    ["upper"]={ 0x1F0E, 0x0399 },
   },
  },
 },
 [0x1F8F]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F87 },
    ["title"]={ 0x1F8F },
    ["upper"]={ 0x1F0F, 0x0399 },
   },
  },
 },
 [0x1F90]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F90 },
    ["title"]={ 0x1F98 },
    ["upper"]={ 0x1F28, 0x0399 },
   },
  },
 },
 [0x1F91]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F91 },
    ["title"]={ 0x1F99 },
    ["upper"]={ 0x1F29, 0x0399 },
   },
  },
 },
 [0x1F92]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F92 },
    ["title"]={ 0x1F9A },
    ["upper"]={ 0x1F2A, 0x0399 },
   },
  },
 },
 [0x1F93]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F93 },
    ["title"]={ 0x1F9B },
    ["upper"]={ 0x1F2B, 0x0399 },
   },
  },
 },
 [0x1F94]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F94 },
    ["title"]={ 0x1F9C },
    ["upper"]={ 0x1F2C, 0x0399 },
   },
  },
 },
 [0x1F95]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F95 },
    ["title"]={ 0x1F9D },
    ["upper"]={ 0x1F2D, 0x0399 },
   },
  },
 },
 [0x1F96]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F96 },
    ["title"]={ 0x1F9E },
    ["upper"]={ 0x1F2E, 0x0399 },
   },
  },
 },
 [0x1F97]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F97 },
    ["title"]={ 0x1F9F },
    ["upper"]={ 0x1F2F, 0x0399 },
   },
  },
 },
 [0x1F98]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F90 },
    ["title"]={ 0x1F98 },
    ["upper"]={ 0x1F28, 0x0399 },
   },
  },
 },
 [0x1F99]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F91 },
    ["title"]={ 0x1F99 },
    ["upper"]={ 0x1F29, 0x0399 },
   },
  },
 },
 [0x1F9A]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F92 },
    ["title"]={ 0x1F9A },
    ["upper"]={ 0x1F2A, 0x0399 },
   },
  },
 },
 [0x1F9B]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F93 },
    ["title"]={ 0x1F9B },
    ["upper"]={ 0x1F2B, 0x0399 },
   },
  },
 },
 [0x1F9C]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F94 },
    ["title"]={ 0x1F9C },
    ["upper"]={ 0x1F2C, 0x0399 },
   },
  },
 },
 [0x1F9D]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F95 },
    ["title"]={ 0x1F9D },
    ["upper"]={ 0x1F2D, 0x0399 },
   },
  },
 },
 [0x1F9E]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F96 },
    ["title"]={ 0x1F9E },
    ["upper"]={ 0x1F2E, 0x0399 },
   },
  },
 },
 [0x1F9F]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1F97 },
    ["title"]={ 0x1F9F },
    ["upper"]={ 0x1F2F, 0x0399 },
   },
  },
 },
 [0x1FA0]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA0 },
    ["title"]={ 0x1FA8 },
    ["upper"]={ 0x1F68, 0x0399 },
   },
  },
 },
 [0x1FA1]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA1 },
    ["title"]={ 0x1FA9 },
    ["upper"]={ 0x1F69, 0x0399 },
   },
  },
 },
 [0x1FA2]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA2 },
    ["title"]={ 0x1FAA },
    ["upper"]={ 0x1F6A, 0x0399 },
   },
  },
 },
 [0x1FA3]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA3 },
    ["title"]={ 0x1FAB },
    ["upper"]={ 0x1F6B, 0x0399 },
   },
  },
 },
 [0x1FA4]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA4 },
    ["title"]={ 0x1FAC },
    ["upper"]={ 0x1F6C, 0x0399 },
   },
  },
 },
 [0x1FA5]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA5 },
    ["title"]={ 0x1FAD },
    ["upper"]={ 0x1F6D, 0x0399 },
   },
  },
 },
 [0x1FA6]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA6 },
    ["title"]={ 0x1FAE },
    ["upper"]={ 0x1F6E, 0x0399 },
   },
  },
 },
 [0x1FA7]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA7 },
    ["title"]={ 0x1FAF },
    ["upper"]={ 0x1F6F, 0x0399 },
   },
  },
 },
 [0x1FA8]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA0 },
    ["title"]={ 0x1FA8 },
    ["upper"]={ 0x1F68, 0x0399 },
   },
  },
 },
 [0x1FA9]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA1 },
    ["title"]={ 0x1FA9 },
    ["upper"]={ 0x1F69, 0x0399 },
   },
  },
 },
 [0x1FAA]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA2 },
    ["title"]={ 0x1FAA },
    ["upper"]={ 0x1F6A, 0x0399 },
   },
  },
 },
 [0x1FAB]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA3 },
    ["title"]={ 0x1FAB },
    ["upper"]={ 0x1F6B, 0x0399 },
   },
  },
 },
 [0x1FAC]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA4 },
    ["title"]={ 0x1FAC },
    ["upper"]={ 0x1F6C, 0x0399 },
   },
  },
 },
 [0x1FAD]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA5 },
    ["title"]={ 0x1FAD },
    ["upper"]={ 0x1F6D, 0x0399 },
   },
  },
 },
 [0x1FAE]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA6 },
    ["title"]={ 0x1FAE },
    ["upper"]={ 0x1F6E, 0x0399 },
   },
  },
 },
 [0x1FAF]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FA7 },
    ["title"]={ 0x1FAF },
    ["upper"]={ 0x1F6F, 0x0399 },
   },
  },
 },
 [0x1FB2]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FB2 },
    ["title"]={ 0x1FBA, 0x0345 },
    ["upper"]={ 0x1FBA, 0x0399 },
   },
  },
 },
 [0x1FB3]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FB3 },
    ["title"]={ 0x1FBC },
    ["upper"]={ 0x0391, 0x0399 },
   },
  },
 },
 [0x1FB4]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FB4 },
    ["title"]={ 0x0386, 0x0345 },
    ["upper"]={ 0x0386, 0x0399 },
   },
  },
 },
 [0x1FB6]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FB6 },
    ["title"]={ 0x0391, 0x0342 },
    ["upper"]={ 0x0391, 0x0342 },
   },
  },
 },
 [0x1FB7]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FB7 },
    ["title"]={ 0x0391, 0x0342, 0x0345 },
    ["upper"]={ 0x0391, 0x0342, 0x0399 },
   },
  },
 },
 [0x1FBC]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FB3 },
    ["title"]={ 0x1FBC },
    ["upper"]={ 0x0391, 0x0399 },
   },
  },
 },
 [0x1FC2]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FC2 },
    ["title"]={ 0x1FCA, 0x0345 },
    ["upper"]={ 0x1FCA, 0x0399 },
   },
  },
 },
 [0x1FC3]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FC3 },
    ["title"]={ 0x1FCC },
    ["upper"]={ 0x0397, 0x0399 },
   },
  },
 },
 [0x1FC4]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FC4 },
    ["title"]={ 0x0389, 0x0345 },
    ["upper"]={ 0x0389, 0x0399 },
   },
  },
 },
 [0x1FC6]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FC6 },
    ["title"]={ 0x0397, 0x0342 },
    ["upper"]={ 0x0397, 0x0342 },
   },
  },
 },
 [0x1FC7]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FC7 },
    ["title"]={ 0x0397, 0x0342, 0x0345 },
    ["upper"]={ 0x0397, 0x0342, 0x0399 },
   },
  },
 },
 [0x1FCC]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FC3 },
    ["title"]={ 0x1FCC },
    ["upper"]={ 0x0397, 0x0399 },
   },
  },
 },
 [0x1FD2]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FD2 },
    ["title"]={ 0x0399, 0x0308, 0x0300 },
    ["upper"]={ 0x0399, 0x0308, 0x0300 },
   },
  },
 },
 [0x1FD3]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FD3 },
    ["title"]={ 0x0399, 0x0308, 0x0301 },
    ["upper"]={ 0x0399, 0x0308, 0x0301 },
   },
  },
 },
 [0x1FD6]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FD6 },
    ["title"]={ 0x0399, 0x0342 },
    ["upper"]={ 0x0399, 0x0342 },
   },
  },
 },
 [0x1FD7]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FD7 },
    ["title"]={ 0x0399, 0x0308, 0x0342 },
    ["upper"]={ 0x0399, 0x0308, 0x0342 },
   },
  },
 },
 [0x1FE2]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FE2 },
    ["title"]={ 0x03A5, 0x0308, 0x0300 },
    ["upper"]={ 0x03A5, 0x0308, 0x0300 },
   },
  },
 },
 [0x1FE3]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FE3 },
    ["title"]={ 0x03A5, 0x0308, 0x0301 },
    ["upper"]={ 0x03A5, 0x0308, 0x0301 },
   },
  },
 },
 [0x1FE4]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FE4 },
    ["title"]={ 0x03A1, 0x0313 },
    ["upper"]={ 0x03A1, 0x0313 },
   },
  },
 },
 [0x1FE6]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FE6 },
    ["title"]={ 0x03A5, 0x0342 },
    ["upper"]={ 0x03A5, 0x0342 },
   },
  },
 },
 [0x1FE7]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FE7 },
    ["title"]={ 0x03A5, 0x0308, 0x0342 },
    ["upper"]={ 0x03A5, 0x0308, 0x0342 },
   },
  },
 },
 [0x1FF2]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FF2 },
    ["title"]={ 0x1FFA, 0x0345 },
    ["upper"]={ 0x1FFA, 0x0399 },
   },
  },
 },
 [0x1FF3]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FF3 },
    ["title"]={ 0x1FFC },
    ["upper"]={ 0x03A9, 0x0399 },
   },
  },
 },
 [0x1FF4]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FF4 },
    ["title"]={ 0x038F, 0x0345 },
    ["upper"]={ 0x038F, 0x0399 },
   },
  },
 },
 [0x1FF6]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FF6 },
    ["title"]={ 0x03A9, 0x0342 },
    ["upper"]={ 0x03A9, 0x0342 },
   },
  },
 },
 [0x1FF7]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FF7 },
    ["title"]={ 0x03A9, 0x0342, 0x0345 },
    ["upper"]={ 0x03A9, 0x0342, 0x0399 },
   },
  },
 },
 [0x1FFC]={
  [""]={
   ["all"]={
    ["lower"]={ 0x1FF3 },
    ["title"]={ 0x1FFC },
    ["upper"]={ 0x03A9, 0x0399 },
   },
  },
 },
 [0xFB00]={
  [""]={
   ["all"]={
    ["lower"]={ 0xFB00 },
    ["title"]={ 0x0046, 0x0066 },
    ["upper"]={ 0x0046, 0x0046 },
   },
  },
 },
 [0xFB01]={
  [""]={
   ["all"]={
    ["lower"]={ 0xFB01 },
    ["title"]={ 0x0046, 0x0069 },
    ["upper"]={ 0x0046, 0x0049 },
   },
  },
 },
 [0xFB02]={
  [""]={
   ["all"]={
    ["lower"]={ 0xFB02 },
    ["title"]={ 0x0046, 0x006C },
    ["upper"]={ 0x0046, 0x004C },
   },
  },
 },
 [0xFB03]={
  [""]={
   ["all"]={
    ["lower"]={ 0xFB03 },
    ["title"]={ 0x0046, 0x0066, 0x0069 },
    ["upper"]={ 0x0046, 0x0046, 0x0049 },
   },
  },
 },
 [0xFB04]={
  [""]={
   ["all"]={
    ["lower"]={ 0xFB04 },
    ["title"]={ 0x0046, 0x0066, 0x006C },
    ["upper"]={ 0x0046, 0x0046, 0x004C },
   },
  },
 },
 [0xFB05]={
  [""]={
   ["all"]={
    ["lower"]={ 0xFB05 },
    ["title"]={ 0x0053, 0x0074 },
    ["upper"]={ 0x0053, 0x0054 },
   },
  },
 },
 [0xFB06]={
  [""]={
   ["all"]={
    ["lower"]={ 0xFB06 },
    ["title"]={ 0x0053, 0x0074 },
    ["upper"]={ 0x0053, 0x0054 },
   },
  },
 },
 [0xFB13]={
  [""]={
   ["all"]={
    ["lower"]={ 0xFB13 },
    ["title"]={ 0x0544, 0x0576 },
    ["upper"]={ 0x0544, 0x0546 },
   },
  },
 },
 [0xFB14]={
  [""]={
   ["all"]={
    ["lower"]={ 0xFB14 },
    ["title"]={ 0x0544, 0x0565 },
    ["upper"]={ 0x0544, 0x0535 },
   },
  },
 },
 [0xFB15]={
  [""]={
   ["all"]={
    ["lower"]={ 0xFB15 },
    ["title"]={ 0x0544, 0x056B },
    ["upper"]={ 0x0544, 0x053B },
   },
  },
 },
 [0xFB16]={
  [""]={
   ["all"]={
    ["lower"]={ 0xFB16 },
    ["title"]={ 0x054E, 0x0576 },
    ["upper"]={ 0x054E, 0x0546 },
   },
  },
 },
 [0xFB17]={
  [""]={
   ["all"]={
    ["lower"]={ 0xFB17 },
    ["title"]={ 0x0544, 0x056D },
    ["upper"]={ 0x0544, 0x053D },
   },
  },
 },
}
