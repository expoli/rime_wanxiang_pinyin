local charsfilter = {}

function charsfilter.init(env)
   -- 使用 ReverseLookup 方法加载字符集
   env.charset = ReverseLookup("charset")
   env.memo = {}
end

function charsfilter.fini(env)
   env.charset = nil
   env.memo = nil
   collectgarbage()
end

function charsfilter.func(t_input, env)
   local extended = env.engine.context:get_option("charset_filter")

   if extended or env.charset == nil or charsfilter.IsReverseLookup(env) then
      for cand in t_input:iter() do
         yield(cand)
      end
   else
      for cand in t_input:iter() do
         if charsfilter.IsSingleChineseCharacter(cand.text) and charsfilter.InCharset(env, cand.text) then
            yield(cand)
         elseif not charsfilter.IsSingleChineseCharacter(cand.text) then
            -- 对于非汉字字符，直接放行
            yield(cand)
         end
      end
   end
end

-- 检查字符是否为单个汉字
function charsfilter.IsSingleChineseCharacter(text)
   return utf8.len(text) == 1 and charsfilter.IsChineseCharacter(text)
end

-- 判断字符是否为汉字
function charsfilter.IsChineseCharacter(text)
   local codepoint = utf8.codepoint(text)
   return (codepoint >= 0x4E00 and codepoint <= 0x9FFF)   -- basic
      or (codepoint >= 0x3400 and codepoint <= 0x4DBF)    -- ext a
      or (codepoint >= 0x20000 and codepoint <= 0x2A6DF)  -- ext b
      or (codepoint >= 0x2A700 and codepoint <= 0x2B73F)  -- ext c
      or (codepoint >= 0x2B740 and codepoint <= 0x2B81F)  -- ext d
      or (codepoint >= 0x2B820 and codepoint <= 0x2CEAF)  -- ext e
      or (codepoint >= 0x2CEB0 and codepoint <= 0x2EBE0)  -- ext f
      or (codepoint >= 0x30000 and codepoint <= 0x3134A)  -- ext g
      or (codepoint >= 0x31350 and codepoint <= 0x323AF)  -- ext h
      or (codepoint >= 0x2EBF0 and codepoint <= 0x2EE5F)  -- ext i
end

-- 检查字符是否在字符集内
function charsfilter.InCharset(env, text)
   for i, codepoint in utf8.codes(text) do
      if not charsfilter.CodepointInCharset(env, codepoint) then
         return false
      end
   end
   return true
end

function charsfilter.CodepointInCharset(env, codepoint)
   -- 如果已经缓存过该字符的处理结果，直接返回
   if env.memo[codepoint] ~= nil then
      return env.memo[codepoint]
   end

   local char = utf8.char(codepoint)
   local res = env.charset:lookup(char) ~= ""
   env.memo[codepoint] = res
   return res
end

function charsfilter.IsReverseLookup(env)
   local seg = env.engine.context.composition:back()
   if not seg then
      return false
   end
   return seg:has_tag("radical_lookup")
      or seg:has_tag("reverse_stroke")
      or seg:has_tag("add_user_dict")
end

return charsfilter
=======
local low_freq_chars = {}

-- 加载低频字符列表
local function load_low_freq_chars(config)
  local chars_filter_threshold = tonumber(config:get_string("chars_filter")) or 1

  local path = rime_api.get_user_data_dir() .. "/cn_dicts/chars.dict.yaml"
  local file = io.open(path, "r")
  if not file then
    return
  end

  -- 用于存储每个字符的所有频率
  local char_freqs = {}

  -- 遍历文件，记录每个字符的所有频率
  for line in file:lines() do
    local char, _, freq_str = line:match("^(.-)\t(.-)\t(.-)$")
    if char and freq_str then
      local freq = tonumber(freq_str)
      if freq then
        if not char_freqs[char] then
          char_freqs[char] = {}
        end
        table.insert(char_freqs[char], freq)
      end
    end
  end
  file:close()

  -- 只加载所有频率都小于等于chars_filter_threshold的字符
  for char, freqs in pairs(char_freqs) do
    local load_char = true
    for _, freq in ipairs(freqs) do
      if freq > chars_filter_threshold then
        load_char = false
        break
      end
    end
    -- 如果所有频率都小于等于chars_filter_threshold，则加入低频表
    if load_char then
      low_freq_chars[char] = true
    end
  end
end

-- 定义过滤器
local filter = {}

-- 初始化时加载低频字符
function filter.init(env)
  local config = env.engine.schema.config
  -- 获取配置并加载低频字符
  load_low_freq_chars(config)

  -- 获取排除模式配置
  local context = env.engine.context
  -- 初始化时检查开关状态
  filter.enabled = context:get_option("charset_display") or false

  filter.is_radical_mode = false

  -- 设置排除模式的正则表达式
  env.settings = {
    radical_lookup = config:get_string("recognizer/patterns/radical_lookup") or "^az[a-z]+$",  -- 排除模式1
    reverse_stroke = config:get_string("recognizer/patterns/reverse_stroke") or "^ab[A-Za-z]*$",  -- 排除模式2
    add_user_dict = config:get_string("recognizer/patterns/add_user_dict") or "^ac[A-Za-z]*$",  -- 排除模式3
  }
end

-- 处理输入并过滤字符
function filter.func(input, env)
  local context = env.engine.context
  -- 动态检查开关状态
  filter.enabled = context:get_option("charset_display") or false

  local is_radical_mode = false

  -- 检测当前输入状态，判断是否需要启用排除模式
  if context.input:len() == 0 then
    is_radical_mode = false  -- 清空输入时退出模式
  elseif context.input:find(env.settings.radical_lookup) then
    is_radical_mode = true  -- 激活部件组字模式
  elseif context.input:find(env.settings.reverse_stroke) then
    is_radical_mode = true  -- 激活笔画组字模式
  elseif context.input:find(env.settings.add_user_dict) then
    is_radical_mode = true  -- 激活自定义字典组字模式
  end

  -- 只有当低频字符过滤开关启用时才进行过滤
  if filter.enabled and not is_radical_mode then
    for cand in input:iter() do
      local text = cand.text
      if low_freq_chars[text] then
        -- 过滤掉低频字符
      else
        yield(cand)
      end
    end
  else
    -- 如果低频字符过滤被禁用，输出所有字符
    for cand in input:iter() do
      yield(cand)
    end
  end
end

return filter