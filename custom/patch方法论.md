



# Rime YAML Custom Patch 语法指南

## 语法表格

| 操作类型       | 语法                      | 说明                         |
| -------------- | ------------------------- | ---------------------------- |
| **新增**       | `key/+:`                  | 在某个列表中追加值           |
| **删除**       | `key/-:`（不可用）        | 从列表中移除值（不可用）     |
| **全局替换**   | `key: new_value`          | 替换整个键的值               |
| **部分替换**   | `key/index/subkey: value` | 修改列表中的特定项           |
| **特定行追加** | engine/filters/@12        | 从0开始计算                  |
| **末尾追加**   | engine/processors/@last   | 不管列表多长他都会追加到末尾 |



---

## 1. **新增值 (`/+`)**
```yaml
patch:
  schema_list/+: 
    - luna_pinyin      # 这是正确的例子：追加这个方案列表为启用状态，多个值列表即可
  schema_list/-: wubi  # 这是一个错误的例子：/-不可被使用
  engine/filters/-:
    - lua_filter@*en_spacer #这是一个错误的例子：/-不可被使用
  menu/page_size: 10   # 这是正确的例子：单独替换最下层具体的值 page_size 值，不影响其他值

  
  更多方式参考rime文档

```



# Rime YAML Patch 机制解析

## 为什么 `menu/page_size: 10` 和 `menu: { page_size: 10 }` 结果不同？

在 **Rime YAML Patch 机制** 下，`menu/page_size: 10` 和 `menu: { page_size: 10 }` **看似等价**，但 **行为是不同的**，主要原因在于 **Patch 机制的覆盖策略**。

- **`menu/page_size: 10`** 仅修改 `menu` 下的 `page_size`，不会影响 `menu` 里的其他键值。
- **`menu: { page_size: 10 }`** **会直接覆盖** `menu`，即 **清空 `menu` 下原有的所有内容**，只留下 `page_size`。

---

**假设一个段落：**

```yaml
menu:
  page_size: 10
  settings:
    font_size: 14
    color: blue

```

**正确写法（不会删除 `settings`）就是局部修改值：**

```yaml
patch:
  menu/page_size: 10
```



**错误写法（会删除 `settings`）就是全局替换：**

```yaml
patch:
  menu:
    - page_size: 10
```

**以下是常用的三种情况：**

```yaml
#整体替换
patch:
  engine:
    translators:
      - table_translator@custom_phrase

```

```yaml
#部分替换
patch:
  engine/translators:
    - table_translator@custom_phrase

```

```yaml
#追加新的内容
patch:
  engine/translators/+:
    - table_translator@custom_phrase

```

也就是说不能用/-，如果想要删除某一行

下面再用两个实际的例子来巩固一下：

```yaml
#由于下面列表值，所以你想删除某一行只能在这里注释掉，还要观察主方案是否提供了新的值，删除某一个单独的值确实是个难点
patch:
  engine/filters:
    - lua_filter@*chars_filter                     
    - lua_filter@*cold_word_drop.filter
    - lua_filter@*assist_sort                       
    - lua_filter@*autocap_filter                    
    - reverse_lookup_filter@radical_reverse_lookup  
    - lua_filter@*pro_preedit_format                
    - simplifier@emoji                            
    - simplifier@traditionalize                     
    - simplifier@mars                               
    - simplifier@chinese_english                    
    - simplifier@zrm_chaifen                        
    - lua_filter@*search@radical_pinyin            
    #- lua_filter@*en_spacer                         
    - lua_filter@*pro_comment_format                
    - uniquifier   
```

```yaml
#但是如果你想删除某一行携带值的整行，有办法了，用如下的表示即可，将现有的值清空，不熟的时候整行也就不会生效了，这一行就不存在了
patch:
  custom_phrase/user_dict:
  custom_phrase/initial_quality:
```
