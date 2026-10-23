import { createRoot } from 'react-dom/client';
import { ButtonMetallicPreview } from '@/components/previews/motion/button-metallic.preview';
import { ButtonBasePreview } from '@/components/previews/motion/button-base.preview';
import { ButtonStatefulPreview } from '@/components/previews/motion/button-stateful.preview';
import { ButtonMagneticPreview } from '@/components/previews/motion/button-magnetic.preview';
import { InlineSliderPreview } from '@/components/previews/motion/range-slider-inline.preview';
import { RangeSliderPreview } from '@/components/previews/motion/range-slider.preview';
import { RangeSliderFluidPreview } from '@/components/previews/motion/range-slider-fluid.preview';
import { RangeSliderWavePreview } from '@/components/previews/motion/range-slider-wave.preview';
import { RangeSliderBubblePreview } from '@/components/previews/motion/range-slider-bubble.preview';
import { RangeSliderRulerPreview } from '@/components/previews/motion/range-slider-ruler.preview';
import { TablePreview } from '@/components/previews/motion/table.preview';
import { TableEditablePreview } from '@/components/previews/motion/table-editable.preview';
import { TableAsyncPreview } from '@/components/previews/motion/table-async.preview';
import { THEMES } from '@/lib/themes';

const examples = {
  metallic: ButtonMetallicPreview, base: ButtonBasePreview,
  stateful: ButtonStatefulPreview, magnetic: ButtonMagneticPreview,
  inline: InlineSliderPreview, stepped: RangeSliderPreview,
  fluid: RangeSliderFluidPreview, wave: RangeSliderWavePreview,
  bubble: RangeSliderBubblePreview, ruler: RangeSliderRulerPreview,
  data: TablePreview, editable: TableEditablePreview, async: TableAsyncPreview,
};
const params = new URLSearchParams(location.search);
const theme = params.get('theme') === 'dark' ? 'dark' : 'light';
document.documentElement.classList.toggle('dark', theme === 'dark');
for (const [key, value] of Object.entries(THEMES.blue[theme])) {
  document.documentElement.style.setProperty(key, value);
}
const Example = examples[params.get('example') ?? 'metallic'];
await Promise.all([400, 500, 600, 700].map(weight => document.fonts.load(`${weight} 14px Geist`)));
createRoot(document.getElementById('root')!).render(<main id="stage"><Example /></main>);
