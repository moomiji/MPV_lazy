# ~~小刻也能看懂的~~自动打包食用指南

虽然大多数人在客制化完mpv后会停留在某个版本，但是mpv并未停止更新，各种画质增强、补帧等工具也在不断更新迭代，这造成自己客制化的mpv的配置也需要不断更新。

如果客制化的mpv是基于MPV_lazy的话，紧跟MPV_lazy的更新会不可避免地出现配置不断被覆盖的情况。

本action脚本正是为了缓解这一情况编写的，当然客制化仍然需要你自己动手，合并MPV_lazy的更新和解决冲突也需要你动动手指，但脚本基于MPV_lazy的lite(版本)分支，可以省下在客制化完成后繁杂的打包工作。

## 它能做什么

通过Github action，执行脚本[pach.sh](/action/pack.sh)，脚本读取[pack.ini](/action/pack.ini)中的配置进行自动打包。

pack.ini中已经预先根据`mpv-lazy-2023V2`版本，编写好了标准版的追新配置（VapourSynth配置为R61版本，不同版本VapourSynth需要不同的Python版本）

通过编写pack.ini配置，可以做到：

- 打包画质增强、补帧等工具的最新或者某个版本

- clone仓库特定版本/分支的某个文件(夹)

- 对windows用户而言，打包特定的mpv.exe

- 从上游仓库main分支的特定commit替换lite分支的占位符文件

具体配置文档请查看[action/READINI.md](/action/READINI.md)

## 如何使用

### 初始化

1. Fork主仓库：[hooke007/MPV_lazy](https://github.com/hooke007/MPV_lazy)

   ![](/Temp/action/fork1.jpg)

   ![](/Temp/action/fork2.jpg)

2. 切换主分支

   主分支也可以是父节点为lite的分支

   ![](/Temp/action/switch.jpg)

3. 合并仓库[moomiji/MPV_lazy](https://github.com/moomiji/MPV_lazy)对lite分支的修改，至Fork仓库中父节点为lite的分支

   ![](/Temp/action/pr1.jpg)

   ![](/Temp/action/pr2.jpg)

   ![](/Temp/action/pr3.jpg)

   ![](/Temp/action/pr4.jpg)
  
### 合并本地的修改

1. 合并你本地的修改至父节点为lite的分支

2. 如果需要上游main分支的某个文件(夹)，请添加同路径的占位符文件

3. 如果不需要上游main分支的某个文件(夹)，请删除同路径的占位符文件

### 合并上游修改

***注意不要点到 Discard***

![](/Temp/action/update.jpg)

### 自动打包

1. 运行自动打包

   ![](/Temp/action/action.jpg)

2. 下载打包文件

   ![](/Temp/action/download1.jpg)

   ![](/Temp/action/download2.jpg)
