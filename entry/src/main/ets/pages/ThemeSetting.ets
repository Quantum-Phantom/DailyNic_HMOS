
import { common, ConfigurationConstant, Want } from '@kit.AbilityKit';
import { fileIo, fileUri } from '@kit.CoreFileKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { photoAccessHelper } from '@kit.MediaLibraryKit';
import UnifiedPreferences from '../utils/UnifyPreference';
import BackgroundImage, { presetColor } from '../utils/BgImageManager';

@Builder
export function ThemeBuilder(name: string, param?: number[]) {
  if (param)
    ThemeSetting({ windowWidth: param[0], windowHeight: param[1] });
  else
    ThemeSetting();
}

function BlurStyleToNum(ori: BlurStyle | undefined): number {
  switch (ori) {
    case BlurStyle.NONE:
      return 0;
    case BlurStyle.COMPONENT_ULTRA_THIN:
      return 1;
    case BlurStyle.COMPONENT_THIN:
      return 2;
    case BlurStyle.COMPONENT_REGULAR:
      return 3;
    case BlurStyle.COMPONENT_THICK:
      return 4;
    case BlurStyle.COMPONENT_ULTRA_THICK:
      return 5;
    default:
      return 3;
  }
}

/**
 * 计算环形进度条的进度
 * @param n 进度条总数
 * @param given 已知进度为50%的编号
 * @param target 目标编号
 * @returns 进度值（0-100之间的数字）
 */
function calculateProgress(n: number, given: number, target: number): number {
  const delta = ((target - given) % n + n) % n;
  const step = 200 / n;
  const quarter = n / 4;
  const threeQuarter = 3 * n / 4;
  let progress: number;
  if (delta >= 0 && delta < quarter) {
    progress = 50 - delta * step;
  } else if (delta >= quarter && delta < threeQuarter) {
    progress = (delta - quarter) * step;
  } else {
    progress = 100 - (delta - threeQuarter) * step;
  }
  return Math.max(0, Math.min(100, progress));
}

const diameter: number = 35;
const distance: number = 90;
const halfSize: number = (diameter >> 1) + distance + 10;
const colorNum: number = presetColor.length;

function posToIndex(x: number, y: number): number {
  let angle = Math.atan2(x - halfSize, halfSize - y);
  if (angle < 0)
    angle += 2 * Math.PI;
  angle += Math.PI / colorNum;
  return Math.trunc(angle * colorNum / (2 * Math.PI)) % 15;
}

@Entry
@Component
struct ThemeSetting {

  private sliderNum: number = BlurStyleToNum(BackgroundImage.blurLevel); // 模糊程度滑动条参数
  @State opacityNum: number = UnifiedPreferences.getNumberSync('OpacityLevel', 100); // 不透明度
  @State isShown: boolean = BackgroundImage.showImage; // 显示预览图片
  @State imgPreview: ResourceStr = (BackgroundImage.imgPath == '') ? $r('app.media.confused') : fileUri.getUriFromPath(BackgroundImage.imgPath); //预览图片
  @State blurNum: BlurStyle = UnifiedPreferences.getNumberSync('BlurLevel', BlurStyle.Regular); // 模糊程度常数
  private selectResult: string | undefined = undefined; // 选择图片的结果
  private oriImgPath: string = ''; // 原始图片路径
  private imageSize: number = 0; // 图片文件大小
  @State showBlurSlider: boolean = BackgroundImage.backgroundBlur;
  windowWidth: number = 1840;
  windowHeight: number = 2800;
  @State showWarning: boolean = false;

  @State colorMode: number = UnifiedPreferences.getNumberSync('ColorMode', ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET);

  @State selectedColor: number = BackgroundImage.themeColor;
  readonly singleRotate: number = 360 / colorNum;

  private oriBlurNum: number = 0;
  private oriOpacityNum: number = 0;

  pathStack: NavPathStack = new NavPathStack();
  menuItems: Array<NavigationMenuItem> = [
    {
      value: $r('app.string.ok_and_restart'),
      icon: $r('app.media.checkmark'),
      action: () => {
        if (this.selectResult !== undefined) {
          const newImgPath: string = BackgroundImage.basicDir + '/backgroundImage';
          fileIo.copyFile(this.oriImgPath, newImgPath)
            .catch((error: BusinessError) => console.error('Copy image failed:', JSON.stringify(error)));
          UnifiedPreferences.putSync('ImagePath', newImgPath);
        }
        if (this.isShown !== BackgroundImage.showImage)
          UnifiedPreferences.putSync('ShowImage', this.isShown);
        if (this.showBlurSlider !== BackgroundImage.backgroundBlur)
          UnifiedPreferences.putSync('BackgroundBlur', this.showBlurSlider);
        if (this.blurNum !== this.oriBlurNum)
          UnifiedPreferences.putSync('BlurLevel', this.blurNum);
        if (this.opacityNum !== this.oriOpacityNum)
          UnifiedPreferences.putSync('OpacityLevel', this.opacityNum);
        if (this.selectedColor !== BackgroundImage.themeColor)
          UnifiedPreferences.putSync('ThemeColor', this.selectedColor);
        UnifiedPreferences.putSync('FaultOccurred', false);

        // 重启
        let applicationContext = (this.getUIContext().getHostContext() as common.UIAbilityContext).getApplicationContext();
        let want: Want = {
          bundleName: 'com.nic.dailynic',
          abilityName: 'EntryAbility'
        };
        try {
          applicationContext.restartApp(want);
        } catch (error) {
          console.error(`restartApp fail, error: ${JSON.stringify(error)}`);
          if (error.code === 16000064) {
            const context = this.getUIContext().getHostContext() as common.UIAbilityContext;
            context.terminateSelf((err) => {
              if (!err) {
                context.getApplicationContext().killAllProcesses().catch((error: Error) => {
                  console.error(`Quitting ERROR: [${error.name}] ${error.message}`);
                })
              }
            });
          }
        }
      }
    }
  ];

  build() {
    NavDestination() {
      Scroll() {
        Column({ space: 16 }) {
          Column() {
            Row({ space: 5 }) {
              Image($r('app.media.shutter_photo'))
                .height(30);
              Text($r('app.string.custom_background'))
                .fontSize(20)
                .fontWeight(FontWeight.Bold);
              Divider()
                .layoutWeight(1);
              Toggle({ isOn: $$this.isShown, type: ToggleType.Switch })
                .onChange((value: boolean) => {
                  if (BackgroundImage.imgPath == '' && this.selectResult == undefined && value) {
                    this.isShown = false;
                    this.SelectImage();
                  }
                });
            }
            .padding(8)
            .width('100%')

            Stack() {
              Image(this.isShown ? this.imgPreview : $r('app.media.confused'))
                .width('95%')
                .alt($r('app.media.confused'))
                .constraintSize({ minHeight: 80, maxHeight: 200 })
                .borderRadius(16)
                .objectFit(ImageFit.Contain)
                .onComplete((value) => {
                  if (value !== undefined) {
                    let swapTemp: number;
                    if (value.width > value.height) {
                      swapTemp = value.width;
                      value.width = value.height;
                      value.height = swapTemp;
                    }
                    if (value.width > this.windowWidth * 3 || value.height > this.windowHeight * 3 ||
                      this.imageSize > 50000000) {
                      this.showWarning = true;
                    } else {
                      this.showWarning = false;
                    }
                  } else {
                    this.showWarning = false;
                  }
                })

              Button($r('app.string.pick_image'))
                .buttonStyle(ButtonStyleMode.NORMAL)
                .backgroundBlurStyle(this.showBlurSlider ? this.blurNum : undefined)
                .opacity(this.showBlurSlider ? 1 : this.opacityNum / 100)
                .onClick(() => {
                  this.SelectImage();
                })
            }
            .margin({ bottom: 5 })

            Row() {
              Text($r('app.string.background_opaque'))
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .fontWeight(this.showBlurSlider ? FontWeight.Normal : FontWeight.Bold)
              Toggle({ isOn: $$this.showBlurSlider, type: ToggleType.Switch })
                .switchStyle({ unselectedColor: $r('sys.color.ohos_id_color_component_activated') })
              Text($r('app.string.background_blur'))
                .layoutWeight(1)
                .textAlign(TextAlign.Center)
                .fontWeight(this.showBlurSlider ? FontWeight.Bold : FontWeight.Normal)
            }

            Row() {
              if (this.showBlurSlider) {
                Text($r('app.string.grid_background_blur'))
                Slider({
                  value: this.sliderNum,
                  min: 0,
                  max: 5,
                  step: 1,
                  style: SliderStyle.InSet
                })
                  .showSteps(true)
                  .layoutWeight(1)
                  .onChange((value: number) => {
                    this.sliderNum = value;
                    switch (value) {
                      case 0:
                        this.blurNum = BlurStyle.NONE;
                        break;
                      case 1:
                        this.blurNum = BlurStyle.COMPONENT_ULTRA_THIN;
                        break;
                      case 2:
                        this.blurNum = BlurStyle.COMPONENT_THIN;
                        break;
                      case 3:
                        this.blurNum = BlurStyle.COMPONENT_REGULAR;
                        break;
                      case 4:
                        this.blurNum = BlurStyle.COMPONENT_THICK;
                        break;
                      case 5:
                        this.blurNum = BlurStyle.COMPONENT_ULTRA_THICK;
                        break;
                    }
                  })
              } else {
                Text($r('app.string.grid_background_opacity'))
                Slider({
                  value: this.opacityNum,
                  min: 25,
                  max: 100,
                  step: 1,
                  style: SliderStyle.InSet
                })
                  .showTips(true, `${this.opacityNum}%`)
                  .layoutWeight(1)
                  .onChange((value: number) => {
                    this.opacityNum = value;
                  });
              }
            }
            .width('95%');

            Text($r('app.string.too_large_bg_image'))
              .width('95%')
              .fontColor($r('app.color.red'))
              .fontSize(15)
              .maxLines(1)
              .visibility(this.showWarning ? Visibility.Visible : Visibility.None);

            Text($r('app.string.custom_background_hint'))
              .fontSize(12)
              .width('95%')
              .margin({ bottom: 10 })
          }
          .margin({ left: 9, right: 9, top: 9 })
          .backgroundBlurStyle(BackgroundImage.blurLevel)
          .borderRadius(23)

          Column() {
            Row() {
              Image($r('app.media.custom_theme_color'))
                .height(30)
                .margin({ right: 5 });
              Text($r('app.string.custom_theme_color'))
                .fontSize(20)
                .fontWeight(FontWeight.Bold)
                .layoutWeight(1)
                .fontColor('#000');
              Text(presetColor[this.selectedColor][2])
                .fontSize(16)
                .margin({ right: 7 })
                .fontColor('#fff');
            }
            .padding(8)
            .borderRadius(BackgroundImage.blurLevel === undefined ? 23 : undefined)
            .linearGradient({
              angle: 90,
              colors: [[presetColor[this.selectedColor][0], 0.0], [presetColor[this.selectedColor][1], 1.0]]
            })

            Text(this.isShown && this.showBlurSlider ? $r('app.string.custom_theme_color_into') : $r('app.string.click_slide_change_color'))
              .fontSize(13)
              .fontColor(this.isShown && this.showBlurSlider ? $r('app.color.red') : undefined)
              .width('95%')
              .textAlign(TextAlign.Center)
              .margin({ bottom: 5, top: 5 })

            Stack({ alignContent: Alignment.Center }) {
              ForEach(presetColor, (singleColor: string[], index: number) => {
                Progress({
                  value: calculateProgress(colorNum, this.selectedColor, index),
                  type: ProgressType.Eclipse
                })
                  .width(diameter)
                  .color(singleColor[0])
                  .backgroundColor(singleColor[1])
                  .offset({
                    x: distance * Math.sin(360 * index / colorNum * (Math.PI / 180)),
                    y: -distance * Math.cos(360 * index / colorNum * (Math.PI / 180))
                  })
                // .onTouch(() => {
                //   this.selectedColor = index;
                // })
              })

              Image($r('app.media.checkmark_green'))
                .width(diameter * 0.6)
                .height(diameter * 0.6)
                .offset({
                  x: distance * Math.sin(360 * this.selectedColor / colorNum * (Math.PI / 180)),
                  y: -distance * Math.cos(360 * this.selectedColor / colorNum * (Math.PI / 180))
                })
            }
            .height(halfSize * 2)
            .width(halfSize * 2)
            .borderStyle(BorderStyle.Dotted)
            .borderWidth(1)
            .borderColor($r('app.color.normal_text'))
            .margin({ bottom: 6 })
            .gesture(
              GestureGroup(GestureMode.Exclusive,
                TapGesture()
                  .onAction((event: GestureEvent) => {
                    this.selectedColor = posToIndex(event.fingerList[0].localX, event.fingerList[0].localY);
                  }),
                PanGesture()
                  .onActionUpdate((event: GestureEvent) => {
                    this.selectedColor = posToIndex(event.fingerList[0].localX, event.fingerList[0].localY);
                  })
              )
            )
          }
          .margin({ left: 9, right: 9 })
          .backgroundBlurStyle(BackgroundImage.blurLevel)
          .borderRadius(BackgroundImage.blurLevel === undefined ? undefined : 23)
          .clip(true)

          Column() {
            Row({ space: 5 }) {
              Image($r('app.media.dark_mode'))
                .height(30);
              Text('更改深浅色模式')
                .fontSize(20)
                .fontWeight(FontWeight.Bold);
              Divider()
                .layoutWeight(1);
              Text('立即生效')
                .margin({ right: 7 });
            }
            .width('100%')
            .padding(8)

            Column() {
              Row() {
                Image($r('app.media.light'))
                  .height(30)
                  .width(30)
                  .margin({ right: 5 })
                Text('浅色')
                  .layoutWeight(1)
                Image($r('app.media.checkmark'))
                  .visibility(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT ? Visibility.Visible : Visibility.Hidden)
                  .height(27)
                  .width(27)
              }
              .width('100%')
              .height(40)
              .onClick(() => {
                if (this.colorMode !== ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT) {
                  this.colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_LIGHT;
                  this.getUIContext().getHostContext()?.getApplicationContext().setColorMode(this.colorMode);
                  UnifiedPreferences.putSync('ColorMode', this.colorMode);
                }
              })
              Divider();
              Row() {
                Image($r('app.media.dark'))
                  .height(24)
                  .width(24)
                  .margin({ right: 8, left: 3 })
                Text('深色')
                  .layoutWeight(1)
                Image($r('app.media.checkmark'))
                  .visibility(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_DARK ? Visibility.Visible : Visibility.Hidden)
                  .height(27)
                  .width(27)
              }
              .width('100%')
              .height(40)
              .justifyContent(FlexAlign.SpaceBetween)
              .onClick(() => {
                if (this.colorMode !== ConfigurationConstant.ColorMode.COLOR_MODE_DARK) {
                  this.colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_DARK;
                  this.getUIContext().getHostContext()?.getApplicationContext().setColorMode(this.colorMode);
                  UnifiedPreferences.putSync('ColorMode', this.colorMode);
                }
              })
              Divider();
              Row() {
                Image($r('app.media.follow_system'))
                  .height(24)
                  .width(24)
                  .margin({ right: 8, left: 3 })
                Text('跟随系统')
                  .layoutWeight(1)
                Image($r('app.media.checkmark'))
                  .visibility(this.colorMode === ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET ? Visibility.Visible : Visibility.Hidden)
                  .height(27)
                  .width(27)
              }
              .width('100%')
              .height(40)
              .justifyContent(FlexAlign.SpaceBetween)
              .onClick(() => {
                if (this.colorMode !== ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET) {
                  this.colorMode = ConfigurationConstant.ColorMode.COLOR_MODE_NOT_SET;
                  this.getUIContext().getHostContext()?.getApplicationContext().setColorMode(this.colorMode);
                  UnifiedPreferences.putSync('ColorMode', this.colorMode);
                }
              })
            }
            .justifyContent(FlexAlign.SpaceEvenly)
            .width('95%')
            .margin({ bottom: 10 })
          }
          .margin({ left: 9, right: 9, bottom: 9 })
          .backgroundBlurStyle(BackgroundImage.blurLevel)
          .borderRadius(23)
        }
        .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
        .width('100%')
      }
      .expandSafeArea([SafeAreaType.SYSTEM], [SafeAreaEdge.BOTTOM])
      .width('100%')
    }
    .title({ main: $r('app.string.theme_setting'), sub: $r('app.string.theme_setting_intro') }, {
      backgroundBlurStyle: BackgroundImage.blurLevel,
      backgroundColor: BackgroundImage.blurLevel === undefined ? $r(`app.color.shaded_background${BackgroundImage.themeColor}`) : undefined
    })
    .backButtonIcon($r('app.media.close'))
    .menus(this.menuItems)
    .backgroundColor(BackgroundImage.blurLevel === undefined ? $r('app.color.normal_background') : '#00d00721')
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      this.oriBlurNum = this.blurNum;
      this.oriOpacityNum = this.opacityNum;
    })
  }

  SelectImage() {
    try {
      const photoSelectOptions = new photoAccessHelper.PhotoSelectOptions();
      photoSelectOptions.MIMEType = photoAccessHelper.PhotoViewMIMETypes.IMAGE_TYPE;
      photoSelectOptions.maxSelectNumber = 1;
      const photoPicker = new photoAccessHelper.PhotoViewPicker();
      photoPicker.select(photoSelectOptions).then((photoSelectResult: photoAccessHelper.PhotoSelectResult) => {
        if (photoSelectResult.photoUris[0] !== undefined) {
          this.selectResult = photoSelectResult.photoUris[0];
          this.oriImgPath = new fileUri.FileUri(this.selectResult).path;
          this.imageSize = fileIo.statSync(this.oriImgPath).size;
          this.imgPreview = photoSelectResult.photoUris[0];
          this.isShown = true;
        }
      }).catch((err: BusinessError) => {
        console.error(`PhotoViewPicker failed: ${JSON.stringify(err)}`)
      })
    } catch (error) {
      console.error(`PhotoViewPicker failed: ${JSON.stringify(error)}`);
    }
  }
}