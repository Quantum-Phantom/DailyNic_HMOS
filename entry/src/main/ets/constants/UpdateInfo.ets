
@Component
export default struct UpdateInfo {
  build() {
    List({ space: 8 }) {
      // ForEach
      ListItem() {
        Column() {
          Text($r('app.string.version_2_0_0_date'))
            .fontWeight(FontWeight.Bolder)
          Text($r('app.string.the_last_update'))
          Row() {
            Text($r('app.string.feat'))
              .fontWeight(FontWeight.Bold)
              .fontSize(14)
              .fontColor($r('app.color.pink'))
              .margin({ right: 5 })
            Divider()
              .layoutWeight(1)
          }
          .margin({ top: 5 })

          Text($r(`app.string.version_2_0_0_feat`))

          Row() {
            Text($r('app.string.fix'))
              .fontWeight(FontWeight.Bold)
              .fontSize(14)
              .fontColor($r('app.color.bright_blue'))
              .margin({ right: 5 })
            Divider()
              .layoutWeight(1)
          }
          .margin({ top: 5 })

          Text($r(`app.string.version_2_0_0_fix`))
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16, right: 16 })
        .padding(16)
        .borderRadius(20)
        .backgroundColor($r('app.color.grid_background'))
      }
      .width('100%')

      ListItem() {
        Column() {
          Text($r('app.string.version_1_0_0_date'))
            .fontWeight(FontWeight.Bolder)
          Row() {
            Text($r('app.string.feat'))
              .fontWeight(FontWeight.Bold)
              .fontSize(14)
              .fontColor($r('app.color.pink'))
              .margin({ right: 5 })
            Divider()
              .layoutWeight(1)
          }
          .margin({ top: 5 })

          Text($r(`app.string.version_1_0_0_feat`))

          Row() {
            Text($r('app.string.fix'))
              .fontWeight(FontWeight.Bold)
              .fontSize(14)
              .fontColor($r('app.color.bright_blue'))
              .margin({ right: 5 })
            Divider()
              .layoutWeight(1)
          }
          .margin({ top: 5 })

          Text($r(`app.string.version_1_0_0_fix`))
        }
        .alignItems(HorizontalAlign.Start)
        .margin({ left: 16, right: 16 })
        .padding(16)
        .borderRadius(20)
        .backgroundColor($r('app.color.grid_background'))
      }
      .width('100%')
    }
    .width('100%')
  }
}