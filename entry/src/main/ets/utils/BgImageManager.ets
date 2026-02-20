
import UnifiedPreferences from './UnifyPreference';
import { fileIo, fileUri } from "@kit.CoreFileKit";

/* probably todo:
可以更改主题色
目前比较好的
> 绿色
light: #E1F2F2
light: #E1FFFF

> 紫色
dark：#2A3166
 */

export const presetColor: string[][] = [
  ['#BEDCF0', '#102542', '冰山蓝调'],
  ['#BEF0C8', '#556B2F', '森屿青柠'],
  ['#D7CDF0', '#2A3166', '暮光紫韵'],
  ['#FAFAD2', '#7A5B00', '杏花春雨'],
  ['#F5D7D7', '#A11616', '桃启绯红'],
  ['#F8F9FA', '#202124', '纸墨绘世'],
  ['#FFF0F6', '#831843', '樱花甜心']
];

class BackgroundImage {
  pic: ResourceStr | undefined = undefined;
  showImage: boolean = UnifiedPreferences.getBoolSync('ShowImage', false); // 是否展示
  readonly imgPath: string = UnifiedPreferences.getSync('ImagePath', ''); // 图片路径
  basicDir: string = '/data/storage/el2/base/files';
  blurLevel: BlurStyle | undefined = undefined;
  opacityLevel: number = 1;
  backgroundBlur: boolean = UnifiedPreferences.getBoolSync('BackgroundBlur', true); // 选择背景模糊
  themeColor: number = UnifiedPreferences.getNumberSync('ThemeColor', 0);

  /**
   * 初始化
   * @param context 传入上下文
   */
  async init(context: Context) {
    if (this.imgPath === '' || !fileIo.accessSync(this.imgPath))
      this.showImage = false;
    if (this.showImage) {
      this.pic = fileUri.getUriFromPath(this.imgPath);
      if (this.backgroundBlur) { // 如果选择背景模糊
        this.blurLevel = UnifiedPreferences.getNumberSync('BlurLevel', BlurStyle.COMPONENT_REGULAR);
        // this.opacityLevel = 1;
      } else { // 如果选择背景透明
        // this.blurLevel = undefined;
        this.opacityLevel = UnifiedPreferences.getNumberSync('OpacityLevel', 100) / 100;
      }
    } else {
      this.pic = undefined;
      // this.blurLevel = undefined;
      // this.opacityLevel = 1;
    }
    this.basicDir = context.filesDir;
  }
}

export default new BackgroundImage();