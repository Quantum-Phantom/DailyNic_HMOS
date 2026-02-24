
import UnifiedPreferences from '../utils/UnifyPreference';
import { common, Want } from '@kit.AbilityKit';
import BackgroundImage, { presetColor } from '../utils/BgImageManager';
import { CircleShape } from '@kit.ArkUI';

/**
 * 计算环形进度条的进度
 * @param n 进度条总数
 * @param given 已知进度为50%的编号
 * @param target 目标编号
 * @returns 进度值（0-100之间的数字）
 */
function calculateProgress(n: number, given: number, target: number): number {
  // 计算顺时针方向的步数
  const delta = ((target - given) % n + n) % n; // 确保结果为非负数

  const step = 200 / n; // 每步变化的百分点

  const quarter = n / 4;
  const threeQuarter = 3 * n / 4;

  let progress: number;

  if (delta >= 0 && delta < quarter) {
    // 第一阶段：50% → 0%（下降）
    progress = 50 - delta * step;
  } else if (delta >= quarter && delta < threeQuarter) {
    // 第二阶段：0% → 100%（上升）
    progress = (delta - quarter) * step;
  } else {
    // 第三阶段：100% → 50%（下降）
    progress = 100 - (delta - threeQuarter) * step;
  }

  // 确保进度在0-100之间（处理浮点数精度问题）
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


@CustomDialog
export default struct ThemeColorDialog {
  controller: CustomDialogController; // 弹窗控制器
  @State selectedColor: number = BackgroundImage.themeColor;
  readonly singleRotate: number = 360 / colorNum;

  build() {
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
      .padding(6)
      .borderRadius(21)
      .margin({ bottom: 4 })
      .linearGradient({
        angle: 90,
        colors: [[presetColor[this.selectedColor][0], 0.0], [presetColor[this.selectedColor][1], 1.0]]
      })

      if (BackgroundImage.blurLevel)
        Text($r('app.string.custom_theme_color_into'))
          .fontColor($r('app.color.red'))
          .fontSize(13)

      Text($r('app.string.click_slide_change_color'))
        .fontSize(13)

      Stack({ alignContent: Alignment.Center }) {
        ForEach(presetColor, (singleColor: string[], index: number) => {
          Progress({ value: calculateProgress(colorNum, this.selectedColor, index), type: ProgressType.Eclipse })
            .width(diameter)
            .color(presetColor[index][0])
            .backgroundColor(presetColor[index][1])
            .offset({ x: distance * Math.sin(360 * index / colorNum * (Math.PI / 180)), y: -distance * Math.cos(360 * index / colorNum * (Math.PI / 180)) })
            // .onTouch(() => {
            //   this.selectedColor = index;
            // })
        })

        Image($r('app.media.selected'))
          .width(diameter * 0.6)
          .height(diameter * 0.6)
          .offset({ x: distance * Math.sin(360 * this.selectedColor / colorNum * (Math.PI / 180)), y: -distance * Math.cos(360 * this.selectedColor / colorNum * (Math.PI / 180)) })
      }
      .height(halfSize * 2)
      .width(halfSize * 2)
      .borderStyle(BorderStyle.Dotted)
      .borderWidth(1)
      .borderColor($r('app.color.normal_text'))
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

      Row() {
        Button($r('app.string.cancel'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .onClick(() => {
            this.controller.close();
          })
          .layoutWeight(1)
        Button($r('app.string.ok_and_restart'))
          .layoutWeight(1)
          // .enabled(!this.showWarning)
          .onClick(() => {
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
            this.controller.close();
          })
      }
      .margin({ top: 5, bottom: 6, right: 6, left: 6 })
    }
    .padding(10)
  }
}