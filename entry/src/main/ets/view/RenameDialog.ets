
@CustomDialog
export default struct RenameDialog {
  controller: CustomDialogController;
  name: string = '';
  onConfirm: (newName: string) => void = () => {};

  build() {
    Column() {
      Row() {
        Image($r('app.media.rename'))
          .height(30)
          .margin({ right: 5 });

        Text($r('app.string.rename'))
          .fontSize(20)
          .fontWeight(FontWeight.Bold)
          .layoutWeight(1)
          .textOverflow({ overflow: TextOverflow.Ellipsis });
      }
      TextInput({ text: this.name })
        .onChange((value: string) => {
          this.name = value;
        })

      Row() {
        Button($r('app.string.cancel'))
          .buttonStyle(ButtonStyleMode.TEXTUAL)
          .width('50%')
          .onClick(() => this.controller.close())

        Button($r('app.string.ok'))
          .buttonStyle(ButtonStyleMode.EMPHASIZED)
          .width('50%')
          .onClick(() => {
            this.onConfirm(this.name);
            this.controller.close();
          })
      }
      .margin({ top: 5 })
    }
    .padding(16)
    .width('100%')
  }
}