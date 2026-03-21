import { rcp } from '@kit.RemoteCommunicationKit';
import { BusinessError } from '@kit.BasicServicesKit';
import BackgroundImage from '../utils/BgImageManager';


@Builder
export function GCBNBuilder(name: string, param?: object) {
  GetClassByName();
}

enum SearchStatus {
  LOADING,
  WAITING_FOR_INPUT,
  GET_DATA_FAILED,
  QUERYING,
  QUERY_SUCCESS,
  QUERY_FAILED
}

@Entry
@Component
struct GetClassByName {

  className: string = '';
  @State requestStatus: SearchStatus = SearchStatus.LOADING;

  pathStack: NavPathStack = new NavPathStack();
  build() {
    NavDestination() {
      Column() {
        if (this.requestStatus === SearchStatus.GET_DATA_FAILED) {
          Image($r('app.media.sorry'))
            .width(100)
          Text() {
            Span('由于接口限制，非校园网环境无法获取课程列表，请连接校园网后')
            Span('重试')
              .fontColor($r('app.color.active_text'))
              .decoration({
                type: TextDecorationType.Underline,
                color: $r('app.color.active_text')
              })
              .onClick(() => {
                this.getData();
              })
            Span('。你无需申请校外访问权限。')
          }
          .textAlign(TextAlign.Center)
          .margin({ top: 6 })
        } else if (this.requestStatus === SearchStatus.LOADING) {
          Row() {
            LoadingProgress()
              .height(30)
            Text($r('app.string.loading'))
          }
        } else if (this.requestStatus === SearchStatus.WAITING_FOR_INPUT) {
          Image($r('app.media.sorry'))
            .width(100)
          Text('获取成功！然而，此功能正在开发中，预计于版本 3.0.0 推出，敬请期待 qwq\nദ്ദി˶˃ ᵕ ˂ )✧')
            .textAlign(TextAlign.Center)
            .margin({ top: 6 })
        }
      }
      .width('100%')
      .padding(16)
    }
    .title(this.customTitle(), {
      backgroundBlurStyle: BackgroundImage.blurLevel,
      backgroundColor: BackgroundImage.blurLevel === undefined ? $r('app.color.shaded_background' + String(BackgroundImage.themeColor)) : undefined
    })
    .backButtonIcon($r('app.media.close'))
    .backgroundColor($r('app.color.normal_background')) // BackgroundImage.showImage ? '#00d00721' :
    .onReady((context: NavDestinationContext) => {
      this.pathStack = context.pathStack;
      this.getData();
    })
  }

  getData() {
    this.requestStatus = SearchStatus.LOADING;
    const getURL = "https://catalog.ustc.edu.cn/api/teach/lesson/list-for-teach/421";
    const session = rcp.createSession();
    session.get(getURL).then((response) => {
      console.info(`Response code: ${response.statusCode}, Response succeeded: ${response}`);
      if (response.statusCode === 200)
        this.requestStatus = SearchStatus.WAITING_FOR_INPUT;
      else
        this.requestStatus = SearchStatus.GET_DATA_FAILED;
    }).catch((err: BusinessError) => {
      console.error(`Response error code is ${err.code}, error data is ${err.data}`);
      this.requestStatus = SearchStatus.GET_DATA_FAILED;
    });
  }

  @Builder customTitle() {
    Row() {
      Search({ value: this.className, placeholder: '按课程名搜索' })
        .onSubmit((value: string) => {
          // this.className = value;
        })
    }
    .padding({ left: 6 })
  }
}