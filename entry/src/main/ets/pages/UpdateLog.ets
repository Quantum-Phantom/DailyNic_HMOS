import { webview } from '@kit.ArkWeb';
import UpdateInfo from '../constants/UpdateInfo';

@Entry
@Component
struct UpdateLog {
  @State agreePolitic: boolean = false;
  @State showSheet: boolean = false;
  private webController: webview.WebviewController | undefined = undefined;

  onBackPress(): boolean {
    return true;
  }

  build() {
    Stepper() {
      StepperItem(){
        Column() {
          Column({ space: 7 }) {
            Image($r('app.media.icon_round'))
              .height(80)
              .width(80)
            Text($r('app.string.have_updated'))
              .fontSize(22)
              .fontWeight(FontWeight.Bold)
              .margin({ top: 10 })
            Text($r('app.string.version_2_0_0_date'))
              .fontSize(16)
              .margin({ top: 5 })
            Text($r('app.string.update_log'))
              .fontSize(16)
              .fontWeight(FontWeight.Bold)
              .margin({ bottom: 10 })
          }

          UpdateInfo()
            .layoutWeight(1)
            .borderWidth(6)
            .borderColor($r('app.color.normal_background'))
            .constraintSize({ maxWidth: 750 })
            .width('95%')
            .borderRadius(20)

          Row() {
            Checkbox()
              .onChange((value: boolean) => {
                this.agreePolitic = value;
              })
            Text() {
              Span($r('app.string.updated_privacy_policy'))
                .fontColor($r('app.color.red'))
              Span($r('app.string.terms_of_use_and_privacy_policy'))
                .fontColor($r('app.color.active_text'))
                .onClick(() => {
                  if (this.webController === undefined)
                    this.webController = new webview.WebviewController();
                  this.showSheet = true;
                })
                .decoration({
                  type: TextDecorationType.Underline,
                  color: $r('app.color.active_text')
                })
            }
            .bindSheet($$this.showSheet, this.agreementSheet(), {
              detents: [SheetSize.LARGE],
              preferType: SheetType.CENTER
            })
          }
          Text($r('app.string.stepper_bug'))
        }
        // .justifyContent(FlexAlign.SpaceAround)
        .margin({ top: 10 })
        .width('90%')
      }
      .nextLabel('妮可，启动！')
      .status(this.agreePolitic ? ItemState.Normal: ItemState.Disabled)
    }
    .onFinish(() => {
      this.getUIContext().getRouter().back();
    })
  }

  @Builder
  agreementSheet() {
    Web({ src: $rawfile('TermsOfUse.html'), controller: this.webController })
      .height('100%')
      .width('100%')
      .darkMode(WebDarkMode.Auto)
      .backgroundColor($r('app.color.normal_background'))
  }
}