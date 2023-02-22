# [pack.ini](/action/pack.ini) 参数解读

[pack.ini](/action/pack.ini)文件由bash脚本读取，修改参数可能需要点简单的bash脚本知识。

- 如果一个变量调用了其他变量，被调变量须在该变量之前填写
- 通配符 *
- 变量值有空格需要用""括起
- 使用变量的方式为"$key_name"
- "7z x -bd -y -o$pack_name $download_file filename/ -x!*/LICENSE.txt"

  按目录层次解压$download_file至$pack_name，只解压filename文件夹并强制覆盖，排除LICENSE.txt

- 7z 解压常用参数：
  - filename：只解压或提取 filename
  - x：按目录层次解压
  - e：提取文件
  - -bd：不显示进度
  - -o：解压至该路径
  - -x!：排除包内的路径
  - -aoa 或 -y：强制覆盖

- mv -f $download_file $pack_name/

  $download_file 移动至 $pack_name/ 文件夹
  - -f：强制覆盖

注：portable_config是这个路径"./portable_config/"，[lazy]才移到$pack_name

## 节
`[这是一个小节]`，打包按`[节]`顺序执行。

## 变量

### 节变量

各节必须有节变量，节变量的值必须小写

| 变量名 | 默认值 | 可用值 | 说明 |
| :-: | :-: | :-: | - |
| run  | true | true \| false | 该小节是否运行 |
| task | init | 见下表 | 该小节的运行任务类型 |

| task | 可用值说明 |
| :-: | - |
| init | 使用`[init]`节中的变量初始化 |
| download | 下载所需文件 |
| clone | 克隆某仓库的文件 |
| lazy | 加糖的克隆（克隆上游仓库main分支，并从上游仓库替换占位符文件） |

### 任务变量

0. task=ini 变量

   `pack_name=mpv_lazy`
   打包后创建的zip压缩文件的名字

   `cmd="mkdir -p $pack_name/vapoursynth64/plugins/models/ && 其他命令 && 其他命令"`
   
   需要在其他任务运行前预先初始化的命令，`cmd=`中的命令使用`&&`进行连接

1. task=download 变量

    优先级：download_url > download_api > github_repo（三变量必选其一）

| 变量名 | 说明 | 必须 |
| :-: | - | :-: |
| github_repo | github仓库名</br>（获取该仓库最新release的github api链接） | *
| download_api | 能从文件名中解析出文件下载链接的链接（目前仅支持api.github.com）</br>一般用于获取最新release文件，可修改脚本的 get_download_url_from_download_api()，支持更多链接 | *
| download_url | 文件下载链接 | *
| download_file | 被下载文件的文件名，可用通配符 | ✓
| cmd | 下载完后执行的命令 |

2. task=clone 变量

    优先级：repository > github_repo

| 变量名 | 说明 | 必须 |
| :-: | - | :-: |
| repository | 指定仓库的链接，可用值举例见下表 |
| github_repo | 指定github仓库的仓库名 | ✓
| ref | 指定仓库的reference值，可用值举例见下表 | ✓
| cmd | 克隆完后执行的命令 |

| 变量名 | 可用值举例 |
| :-: | - |
| repository | https://xxxx.com/hooke007/example.git</br>git@xxxx.com:hooke007/example.git |
| github_repo | 若使用repository，github_repo=hooke007/example |
| ref | 若使用repository，ref=(branch commit) |
| ref | 若仅使用github_repo</br>latest_release</br>refs/heads/main</br>main</br>refs/tags/20230127</br>20230127</br>0509dec3de42cbfe192ee228b2ba60119b72fab5</br>0509dec |

3. task=lazy 变量

    优先级：repository > github_repo

    变量和task=clone一致

| 变量名 | 说明 | 必须 |
| :-: | - | :-: |
| repository | 指定仓库的链接，可用值举例见上表 |
| github_repo | 上游github仓库，默认值：hooke007/MPV_lazy | ✓
| ref | 上游仓库的main分支reference值，可用值举例见上表 | ✓
| cmd | 克隆完后，加糖前执行的命令 |
