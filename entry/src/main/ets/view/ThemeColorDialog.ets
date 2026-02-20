
import UnifiedPreferences from '../utils/UnifyPreference';
import { common, Want } from '@kit.AbilityKit';
import BackgroundImage, { presetColor } from '../utils/BgImageManager';
import { CircleShape } from '@kit.ArkUI';

@CustomDialog
export default struct ThemeColorDialog {
  controller: CustomDialogController; // 弹窗控制器
  private colorNum: number = presetColor.length;
  @State selectedColor: number = BackgroundImage.themeColor;

  build() {
    Column() {
      Row() {
        Image($r('app.media.custom_theme_color'))
          .height(30)
          .margin({ right: 5 });
        Text($r('app.string.custom_theme_color'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1);
        Text(presetColor[this.selectedColor][2])
          .fontSize(16)
          .margin({ right: 7 })
      }

      Stack({ alignContent: Alignment.Center }) {
        ForEach(presetColor, (singleColor: string[], index: number) => {
          Row() {
            Rect()
              .width(25)
              .height(50)
              .fill(singleColor[0])
            Rect()
              .width(25)
              .height(50)
              .fill(singleColor[1])
          }
          .clipShape(new CircleShape({ width: 50, height: 50 }))
          .width(50)
          .offset({ x: 75 * Math.sin(360 * index / this.colorNum * (Math.PI / 180)), y: -75 * Math.cos(360 * index / this.colorNum * (Math.PI / 180)) })
          .justifyContent(FlexAlign.Start)
          .onClick(() => {
            this.selectedColor = index;
          })
        })

        Image($r('app.media.selected'))
          .width(30)
          .height(30)
          .offset({ x: 75 * Math.sin(360 * this.selectedColor / this.colorNum * (Math.PI / 180)), y: -75 * Math.cos(360 * this.selectedColor / this.colorNum * (Math.PI / 180)) })
      }
      .height(200)

      if (BackgroundImage.blurLevel)
        Text($r('app.string.custom_theme_color_into'))
          .fontColor($r('app.color.red'))
          .fontSize(15)

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
      .margin({ top: 5 })
    }
    .padding(16)
  }
}