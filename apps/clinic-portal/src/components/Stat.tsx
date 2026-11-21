export function Stat({ k, v, n, warn }: { k: string; v: string | number; n?: string; warn?: boolean }) {
  return (
    <div className={"card stat" + (warn ? " warn" : "")}>
      <div className="k">{k}</div>
      <div className="v">{v}</div>
      {n && <div className="n">{n}</div>}
    </div>
  );
}
