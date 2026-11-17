import Foundation

// 石・遺物・階の帯の名前と説明（日本語と英語）

extension StoneKind {
    var name: String {
        switch self {
        case .plain: tr("ふつうの石", "Plain stone")
        case .anchor: tr("錨の石", "Anchor Stone")
        case .flame: tr("炎の石", "Flame Stone")
        case .hourglass: tr("時の石", "Hourglass Stone")
        case .gold: tr("金の石", "Gold Stone")
        case .echo: tr("こだまの石", "Echo Stone")
        case .ghost: tr("幽霊の石", "Ghost Stone")
        case .comet: tr("彗星の石", "Comet Stone")
        }
    }

    var detail: String {
        switch self {
        case .plain: tr("挟んで返す、いつもの石。", "The usual: sandwich to flip.")
        case .anchor: tr("置いたら、もう返されない。隅や辺で強い。", "Once placed, it can never be flipped.")
        case .flame: tr("置いた横の列の相手の石を、すべて返す。", "Flips every rival stone in its row.")
        case .hourglass: tr("挟まなくても置ける。2 手後、まわりの石を返す。", "Place anywhere. Two turns later, it flips its neighbors.")
        case .gold: tr("終わったとき 3 つぶんに数える。返されると相手のもの。", "Counts as 3 at the end, for whoever holds it.")
        case .echo: tr("置いたあと、もう 1 手打てる。", "Take another turn right away.")
        case .ghost: tr("穴の上にも置ける。", "Can be placed over a pit.")
        case .comet: tr("置いた縦の列の相手の石を、すべて返す。", "Flips every rival stone in its column.")
        }
    }
}

extension Relic {
    var name: String {
        switch self {
        case .cornerstone: tr("隅の礎石", "Cornerstone")
        case .prism: tr("光のプリズム", "Light Prism")
        case .quiver: tr("石袋", "Stone Pouch")
        case .pickaxe: tr("つるはし", "Pickaxe")
        case .goldVein: tr("金の鉱脈", "Gold Vein")
        case .lantern: tr("灯籠", "Lantern")
        case .embers: tr("残り火", "Embers")
        }
    }

    var detail: String {
        switch self {
        case .cornerstone: tr("あなたの隅の石は +2 点。", "Your corner stones score +2.")
        case .prism: tr("金のはめこみの上の石が ×3 点。", "Stones on gold inlays score ×3.")
        case .quiver: tr("階の始めに、持っている石が 1 つ増える。", "Gain one of your stones each floor.")
        case .pickaxe: tr("盤の穴が少なくなる。", "Fewer pits on every board.")
        case .goldVein: tr("金のはめこみが増える。", "More gold inlays on every board.")
        case .lantern: tr("ヒントが何度でも使える。", "Unlimited hints.")
        case .embers: tr("10 点差以上で勝つと、石が 1 つ増える。", "Win by 10+ to gain a stone.")
        }
    }

    /// 印（SF Symbols の名前）
    var symbol: String {
        switch self {
        case .cornerstone: "square.split.bottomrightquarter"
        case .prism: "triangle"
        case .quiver: "bag"
        case .pickaxe: "hammer"
        case .goldVein: "diamond"
        case .lantern: "lightbulb"
        case .embers: "flame"
        }
    }
}

extension Zone {
    var name: String {
        switch self {
        case .moss: tr("苔の回廊", "Mossy Halls")
        case .crystal: tr("水晶の洞", "Crystal Grotto")
        case .magma: tr("溶岩の炉", "Magma Forge")
        case .star: tr("星の底", "Starfloor")
        }
    }

    var floors: String {
        switch self {
        case .moss: tr("1〜3 階", "Floors 1–3")
        case .crystal: tr("4〜6 階", "Floors 4–6")
        case .magma: tr("7〜9 階", "Floors 7–9")
        case .star: tr("10 階〜", "Floors 10+")
        }
    }
}

extension Reward {
    var title: String {
        switch self {
        case .stones(let kind, let n): trf("%@ ×%d", "%@ ×%d", kind.name, n)
        case .relic(let r): r.name
        case .torch: tr("灯をひとつ", "One more torch")
        }
    }

    var detail: String {
        switch self {
        case .stones(let kind, _): kind.detail
        case .relic(let r): r.detail
        case .torch: tr("負けても、同じ階をもう一度やり直せる。", "Lose a floor, and you can try it again.")
        }
    }

    var kindLabel: String {
        switch self {
        case .stones: tr("宝石", "Gems")
        case .relic: tr("遺物", "Relics")
        case .torch: tr("灯", "Torch")
        }
    }
}
