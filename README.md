# 밧줄을 태우지 마라 (Don't Burn the Rope)

가만히 있으면 밧줄이 탄다.

마우스와 키보드에서 손을 떼면, 화면 가운데에 밧줄이 나타나 타들어 간다. 75초. 하스스톤에서 턴이 끝나 갈 때 나타나는 그 밧줄이다. 손을 대는 순간 사라진다.

When you stop touching the mouse and keyboard, a fuse appears across the screen and starts to burn. Seventy-five seconds, the length of a Hearthstone turn. Touch anything and it is gone.

## 웹 (Web)
`web/index.html`. 탭에서 5초 동안 아무것도 하지 않으면 탄다. `?t=10`으로 기다리는 시간을 바꾼다. 한 번 누르면 소리가 난다.

## macOS
`mac/`. 화면 전체 위에 투명하게 떠서, 컴퓨터 전체의 입력이 멈추면 탄다. 메뉴 막대의 불꽃 아이콘에서 기다리는 시간(3초~5분), 소리, 잠시 끄기를 고른다.

```
cd mac && ./build.sh && open "밧줄을 태우지 마라.app"
```

## 만든 방법 (How)
- WebGL2. 밧줄은 사진 텍스처를 노멀맵으로 조명하고, 타는 앞쪽 뒤로 숯 토막이 남는다.
- 불티는 공기 저항과 중력을 받는 입자이고, 식으면서 흑체 색으로 변한다. 일부는 공중에서 갈라진다.
- 연기는 컬 노이즈를 따라 꼬이며 올라간다. 빛은 HDR 버퍼에 모아 번지게 한다.
- 소리는 걸러 낸 잡음 위에 작은 터짐을 무작위로 얹어 만든다.
- 밧줄과 불꽃 텍스처는 이미지 생성으로 새로 만들었다(`tools/`). 게임 에셋은 쓰지 않았다.

김정훈, 2026. Soft Coding Club.
