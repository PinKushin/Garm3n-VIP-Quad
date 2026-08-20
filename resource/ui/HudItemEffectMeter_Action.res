// TF2 asks for this file for Action-slot items (canteens and similar) and neither
// stock TF2 nor this HUD shipped one, producing a repeating console error:
//
//   Failed to load resource/UI/HudItemEffectMeter_Action.res
//   resource/UI/HudItemEffectMeter_Action.res missing ContinuousProgressBar field "ItemEffectMeter"
//
// All three maintained reference HUDs (rayshud, flawhud, budhud) ship this file for
// the same reason, and rayshud does it exactly this way -- a single #base at the
// meter this HUD already defines, which supplies the ItemEffectMeter control the
// client is looking for.
#base "HudItemEffectMeter.res"
