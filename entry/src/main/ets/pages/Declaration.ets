import { webview } from '@kit.ArkWeb';
import UnifiedPreferences from '../utils/UnifyPreference';
import { setUSTCLink, setHUSTLink } from '../constants/Links';
import UpdateInfo from '../view/UpdateInfo';

@Entry
@Component
struct Declaration {
  @State agreePolitic: boolean = false;
  @State chooseSchool: number = -1;
  @State showSheet: boolean = false;
  @State knowIndependence: boolean = false;
  private webController: webview.WebviewController | undefined = undefined;
  private swiperController: SwiperController = new SwiperController();
  @State index: number = 0;
  @State allowSwipe: boolean = true;

  onBackPress(): boolean {
    return true;
  }

  build() {
    Column() {
      Swiper(this.swiperController) {
        // 同意用户协议和隐私政策
        Column() {
          Column() {
            Column({ space: 7 }) {
              Image($r('app.media.icon_round'))
                .height(80)
                .width(80)
              Text($r('app.string.welcome_to_your_ustc'))
                .fontSize(22)
                .fontWeight(FontWeight.Bold)
                .margin({ top: 10 })
            }

            Column() {
              Row() {
                Checkbox()
                  .onChange((value: boolean) => {
                    this.agreePolitic = value;
                  })
                Text() {
                  Span($r('app.string.read_privacy_policy'))
                  Span($r('app.string.terms_of_use_and_privacy_policy'))
                    .fontColor($r('app.color.active_text'))
                    .onClick(() => {
                      if (this.webController === undefined) {
                        this.webController = new webview.WebviewController();
                      }
                      this.showSheet = true;
                    })
                    .decoration({
                      type: TextDecorationType.Underline,
                      color: $r('app.color.active_text')
                    })
                }
                .bindSheet($$this.showSheet, this.agreementSheet(), {
                  detents: [SheetSize.LARGE],
                  preferType: SheetType.CENTER,
                  title: { title: $r('app.string.terms_of_use_and_privacy_policy'), subtitle: $r('app.string.version') }
                })
              }
            }
          }
          .justifyContent(FlexAlign.SpaceAround)
          .padding(15)
          .height('100%')
          .width('100%')
        }

        Column({ space: 7 }) {
          Text($r('app.string.no_association1'))
            .fontSize(24)
            .fontWeight(FontWeight.Bolder)
          Scroll() {
            Text($r('app.string.no_association2'))
              .fontColor($r('app.color.red'))
          }

          Text($r('app.string.no_association3'))
            .copyOption(CopyOptions.InApp)
          TextArea()
            .maxLines(4)
            .onChange((value: string) => {
              if (value === '我已知晓并承认“妮可之记”由中科大学生独立开发，与华中科技大学和中国科学技术大学官方无任何关联') {
                this.knowIndependence = true;
              }
            })
          Text($r('app.string.no_association4'))
            .fontColor($r('app.color.green'))
            .visibility(this.knowIndependence ? Visibility.Visible : Visibility.Hidden)
        }
        .justifyContent(FlexAlign.Center)
        .padding(15)
        .height('100%')
        .width('100%')

        Column({ space: 7 }) {
          Text($r('app.string.choose_school'))
            .fontSize(24)
            .fontWeight(FontWeight.Bolder)
          Select([{ value: '华中科技大学' }, { value: '中国科学技术大学' }])
            .onSelect((index: number) => {
              this.chooseSchool = index;
            })
          Text($r('app.string.will_support_school'))
            .fontSize(12)
            .fontColor($r('app.color.transparent_text'))
        }
        .justifyContent(FlexAlign.Center)
        .padding(15)
        .height('100%')
        .width('100%')

        Column() {
          Text($r('app.string.update_log'))
            .fontSize(18)
            .fontWeight(FontWeight.Bold)
            .margin({ bottom: 10 })
          UpdateInfo()
            .layoutWeight(1)
        }
        .margin(10)
        .padding({ top: 10, bottom: 20 })
        .borderRadius(20)
        .backgroundColor($r('app.color.normal_background'))
        .height('100%')
        .width('100%')
      }
      .layoutWeight(1)
      .disableSwipe(true)
      .loop(false)
      // .onAnimationStart(() => this.allowSwipe = false)
      .onAnimationEnd(() => this.allowSwipe = true)
      .onChange((index) => {
        this.index = index;
      })

      Row() {
        Button($r('app.string.last_step'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .enabled(this.allowSwipe)
          .visibility(this.index === 0 ? Visibility.Hidden : Visibility.Visible)
          .onClick(() => {
            this.allowSwipe = false;
            this.swiperController.showPrevious();
          })
        Blank()
        Button(this.index === 3 ? $r('app.string.nic_launch') : $r('app.string.next_step'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .enabled((this.index !== 0 || this.agreePolitic) && (this.index !== 1 || this.knowIndependence) && (this.index !== 2 || this.chooseSchool !== -1) && this.allowSwipe)
          .onClick(() => {
            if (this.index === 3) {
              switch (this.chooseSchool) {
                case 0:
                  UnifiedPreferences.putSync('school', 'HUST');
                  setHUSTLink();
                  break;
                case 1:
                  UnifiedPreferences.putSync('school', 'USTC');
                  setUSTCLink();
                  break;
              }
              UnifiedPreferences.putSync('InitialLaunch', false);
              UnifiedPreferences.putSync('AppVersion', '2.0.0');
              this.getUIContext().getRouter().back();
            } else {
              this.allowSwipe = false;
              this.swiperController.showNext();
            }
          })
      }
      .width('100%')
    }
    .height('100%')
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