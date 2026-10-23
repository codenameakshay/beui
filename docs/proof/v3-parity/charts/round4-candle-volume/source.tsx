import React, {useEffect, useState} from 'react';
import {createRoot} from 'react-dom/client';
import {CandlestickChart} from '/tmp/beui-charts-reference-20261023/components/charts/candlestick-chart';
import {VolumeProfile} from '/tmp/beui-charts-reference-20261023/components/charts/volume-profile';

const query = new URLSearchParams(location.search);
const volumes = [18,27,36,52,70,96,135,172,205,241,278,225,192,146,108,79,56,42,31,22,16,11,8,5];
let close = 2380;
const candles = Array.from({length: 48}, (_, i) => {
  const open = close;
  close = open * (1 + Math.sin(i * .7) * .004 + Math.cos(i * .23) * .003);
  const reach = Math.abs(close - open) * .6 + 1.5 + Math.abs(Math.sin(i * 1.9)) * 3;
  return {id: String(i), label: `${12 + Math.floor(i / 12)}:${String(i % 12 * 5).padStart(2,'0')}`,
    open, close, high: Math.max(open,close) + reach * Math.abs(Math.cos(i * 1.3)),
    low: Math.min(open,close) - reach * Math.abs(Math.sin(i * .9)), volume: 120 + Math.abs(Math.sin(i * .6)) * 420};
});

function Fixture() {
  const [data, setData] = useState('original');
  useEffect(() => {
    const listener = (e: KeyboardEvent) => {
      if (e.key.toLowerCase() === 'r') setData('replaced');
      if (e.key.toLowerCase() === 'e') setData('empty');
      if (e.key.toLowerCase() === 'i') setData('original');
    };
    window.addEventListener('keydown', listener);
    return () => window.removeEventListener('keydown', listener);
  }, []);
  const bins = data === 'empty' ? [] : volumes.map((volume, i) => ({
    id: data === 'replaced' ? `new-${i}` : `price-${64000 + i * 100}`,
    priceLow: 64000 + i * 100, priceHigh: 64100 + i * 100, volume,
  }));
  return <main style={{width: Number(query.get('width') || 576)}}>
    <p style={{textAlign:'center', marginBottom:24}}>R replaces IDs. E empties. I restores.</p>
    {query.get('chart') === 'candle'
      ? <CandlestickChart candles={data === 'empty' ? [] : candles} lastPrice={data === 'empty' ? undefined : candles.at(-1)!.close}
          formatPrice={v => v.toLocaleString('en-US',{minimumFractionDigits:2,maximumFractionDigits:2})} />
      : <VolumeProfile data={bins} unit="BTC" label="BTC volume profile"
          formatPrice={v => `$${v.toLocaleString('en-US',{maximumFractionDigits:0})}`} formatVolume={v => v.toLocaleString('en-US')} />}
  </main>;
}
document.documentElement.classList.toggle('dark', query.get('theme') !== 'light');
createRoot(document.getElementById('root')!).render(<Fixture />);
