# The Sphere AMM

## Formula

Orbital is built on top of the Sphere AMM

$$||\vec{r} - \vec{x}||^2 = \sum_{i=1}^{n}(r - x_i)^2 = r^2$$

where $x_i$ is AMM's reserve of asset $i$.

To see that the minimum reserve of any asset is 0, note that the sphere is centered at $\vec{r} = (r, r, \ldots, r)$, and the farthest a point on the sphere can be from the center in any dimension is the radius $r$.

As long as asset prices are positive, no-arbitrage implies we should never have reserves $x_i > r$ for any $i$, since if $x_i = r + d$ for some $d > 0$, then $(r - x_i)^2 = d^2 = (r - (r - d))^2 = (r - (x_i - 2d))^2$ and some trader could remove $2d$ of asset $i$ for free without affecting the AMM's constant function constraint, and by assumption it would have positive value. Therefore we won't add an explicit constraint for $x_i \leq r$ to the AMM, but can assume that $x_i \leq r$ for all $i$ in normal circumstances.

---

# Token Prices on the Sphere

Let's say a trader wants to give the AMM some token $X_i$ and take out some token $X_j$ while staying on the surface $F(\vec{x}) = ||\vec{r} - \vec{x}||^2 = r^2$

In this case, we must have

$$\frac{\delta F}{\delta x_i} \delta x_i + \frac{\delta F}{\delta x_j} \delta x_j = 0$$

so, abusing notation a bit, we can express the instantaneous price of one unit of $x_j$ as

$$\frac{\delta x_i}{\delta x_j} = -\frac{\delta F}{\delta x_j} \bigg/ \frac{\delta F}{\delta x_i} = \frac{r - x_j}{r - x_i}$$

Intuitively we can verify that if the AMM has high reserves of $X_j$ and low reserves of $X_i$, this fraction will be small, meaning you don't get much $X_i$ per unit of $X_j$, and vice versa.

---

# The Equal Price Point

The most important point on the surface of our AMM is the point where all reserves are equal, so that, by symmetry, all prices are equal.

This should be the normal state for stablecoins, because under normal conditions they should all worth the value they are pegged to, e.g. \$1.

Let's denote this point

$$\vec{q} = (q, q, \ldots, q)$$

By our sphere constraint, we have

$$r^2 = ||\vec{r} - \vec{q}||^2 = \sum_{i=1}^{n}(r - q)^2 = n(r - q)^2$$

So then

$$(r - q)^2 = \frac{r^2}{n} \Rightarrow r - q = \frac{r}{\sqrt{n}}$$

so

$$q = r\left(1 - \sqrt{\frac{1}{n}}\right)$$

and we have

$$\vec{q} = r\left(1 - \sqrt{\frac{1}{n}}\right)(1, 1, \ldots, 1)$$

Since they're all multiples of $(1, 1, \ldots, 1)$, there's a line from the origin, through the equal price point, and to the center of the AMM. We can represent its direction with the unit vector

$$\vec{v} = \frac{1}{\sqrt{n}}(1, 1, \ldots, 1)$$

In terms of trading, we can think of $\vec{v}$ as a portfolio of $\frac{1}{\sqrt{n}}$ of each of the coins in the AMM.

---

# Polar Reserve Decomposition

This section introduces a concept and notation we'll be using to work with ticks through the rest of the paper.

Given any valid reserve state $\vec{x}$ on the surface of the AMM, linear algebra tells us we can decompose it into a vector parallel to $\vec{v}$ and a vector $\vec{w}$ orthogonal to $\vec{v}$, the vector from the origin to the equal price point.

In other words, for any reserve state $\vec{x}$, we have

$$\vec{x} = \alpha\vec{v} + \vec{w} \quad \text{where} \quad \vec{v} \perp \vec{w}$$

Note that because $\vec{v}$ is a unit vector, we can calculate $\alpha$ directly as $\vec{x} \cdot \vec{v}$, which mechanically equals $\frac{1}{\sqrt{n}} \sum_{i=1}^{n} x_i$ — $\frac{1}{\sqrt{n}}$ times the sum of all reserves in $\vec{x}$.

Viewed through the lens of this decomposition, our AMM constraint becomes

$$r^2 = ||\vec{x} - r||^2 = ||(\alpha\vec{v} + \vec{w}) - r \cdot \vec{1}||^2 = ||(\alpha\vec{v} + \vec{w}) - r\sqrt{n} \cdot \vec{v}||^2 = ||(\alpha - r\sqrt{n})\vec{v} + \vec{w}||^2$$

Since $\vec{v} \perp \vec{w}$ by definition, we can use the Pythagorean theorem to simplify this to

$$r^2 = (\alpha - r\sqrt{n})^2 + ||\vec{w}||^2$$

or, rearranging,

$$||\vec{w}||^2 = r^2 - (\alpha - r\sqrt{n})^2$$

From this, we can see that if we hold the component of reserves parallel to $\vec{v}$ constant, our AMM acts as a lower-dimensional spherical AMM in the subspace orthogonal to $\vec{v}$ with radius

$$s = \sqrt{r^2 - (\alpha - r\sqrt{n})^2}$$

---

# Tick Definition

## Notes

In the interest of simplicity, for the rest of the paper we will act as if each tick has only one liquidity provider. Of course, in practice, we would allow multiple LPs to pool their liquidity into the same tick, just like in Uniswap V3.

As a reminder, ticks in Orbital are nested. Each is centered at the equal price point, and larger ticks fully overlap with smaller ticks. This is in contrast to Uniswap V3, where ticks are fully disjoint.

## Geometric Intuition

We can think of a tick geometrically as all the points on the sphere's surface that are within some fixed geodesic distance from the equal-price point.

In the 3D case visualized above, it's possible to intuit that we can construct the boundary of such a tick by slicing the sphere with a plane orthogonal to the vector $\vec{v}$ from the equal price point to the sphere's center.

We formalize this construction for higher dimensions below.

## Tick Boundary Geometry

Any plane normal to $\vec{v} = \left(\frac{1}{\sqrt{n}}, \frac{1}{\sqrt{n}}, \ldots, \frac{1}{\sqrt{n}}\right) \in \mathbb{R}^n$ has the form

$$\vec{x} \cdot \vec{v} = k$$

This is another way of saying that the plane consists precisely of all points whose projection on $\vec{v}$ is $k$ — i.e. the points of the form $k\vec{v} + \vec{w}$ for some $\vec{w} \perp \vec{v}$, which you get by starting from $k\vec{v}$ and adding some vector orthogonal to $\vec{v}$.

From the polar reserve decomposition section above, we can see that when reserves lie on this boundary, since the component of reserves parallel to $\vec{v}$ is constant at $k\vec{v}$, the tick AMM functions as a spherical AMM in the $n-1$-dimensional subspace orthogonal to $\vec{v}$ with radius $s = \sqrt{r^2 - (k - r\sqrt{n})^2}$ and center $(k - r\sqrt{n})\vec{v}$.

By symmetry, every point on this boundary will have an equal geodesic distance from the equal price point.

---

# Tick Size Bounds

This section is relatively technical and defines the sizes of the smallest and largest ticks that make sense.

## The Minimal Tick

The minimal tick boundary would be the equal price point itself, which we derived above as the point $\vec{q}$ where

$$x_i = r\left(1 - \sqrt{\frac{1}{n}}\right)$$

for all $i$.

In that case $\vec{x} \cdot \vec{1} = r(n - \sqrt{n})$, and since $\vec{v} = \frac{1}{\sqrt{n}}\vec{1}$, we can define this tick using the plane constant

$$k_{\min} = \vec{x} \cdot \vec{v} = \frac{\vec{x} \cdot \vec{1}}{\sqrt{n}} = r(\sqrt{n} - 1)$$

## The Maximal Tick

The maximal tick's boundary is defined by the plane that lets us achieve the highest possible value of $\vec{x} \cdot \vec{v}$ that doesn't require any reserve $x_i$ to go above $r$. This happens when one reserve $x_j$ reaches its minimum value of 0 while all other reserves are at the maximum, $r$.

For example, consider $x_1 = 0$ and $x_2 = x_3 = \cdots = x_n = r$.

It's still on the sphere because

$$\sum_{i=1}^{n}(r - x_i)^2 = r^2 + \sum_{i=2}^{n}(r - r)^2 = r^2$$

and we have

$$k_{\max} = \vec{x} \cdot \vec{v} = \frac{0 + (n-1)r}{\sqrt{n}} = r\frac{n-1}{\sqrt{n}}$$

To see that this is indeed the maximal tick boundary, note that the reserves of all tokens but $X_1$ are already at their maximum of $r$ assuming positive prices. So, the only way we might be able to increase $\vec{x} \cdot \vec{v}$ further would be to increase the reserves of $X_1$ while decreasing the other reserves by a lesser amount so that we don't violate the AMM constant.

But note that the gradient of $||\vec{r} - \vec{x}||^2$ is

$$2(\vec{r} - \vec{x}) = (r, 0, \ldots, 0)$$

at this point. So if the AMM reduces its $x_2$ reserves infinitesimally, because of the 0 gradient we won't decrease the value of the AMM constant $||\vec{x} - r||^2$ at all. That means so we can't increase $x_1$ to compensate, and this indeed is the maximum tick boundary.

---

# Tick Reserve Bounds and Virtual Reserves

This section explores how tick boundaries affect the minimum and maximum token reserves a tick can hold, and the implications that has for capital efficiency.

## Minimum Reserves

Consider an Orbital tick with a plane constraint of

$$\vec{x} \cdot \vec{v} = k$$

Let's derive the minimum possible reserves of any one of the coins, which we'll denote as $X_{\min}$. By symmetry, the reserves of all the other $X_{\text{other}}$ must be equal to one another at that point.

Our sphere constraint then becomes

$$(r - x_{\min})^2 + (n - 1)(r - x_{\text{other}})^2 = r^2$$

and our plane invariant becomes

$$\frac{1}{\sqrt{n}}\left((n - 1)x_{\text{other}} + x_{\min}\right) = k$$

so that

$$x_{\text{other}} = \frac{\sqrt{n}k - x_{\min}}{n - 1}$$

Solving the resulting quadratic equation for $x_{\min}$ we get

$$x_{\min} = \frac{k\sqrt{n} - \sqrt{k^2 n - n\left((n-1)r - k\sqrt{n}\right)^2}}{n}$$

In terms of trading, this will usually represent the situation where all coins but one depeg to a low value, causing traders to remove as much of that still-stable coin as they can from the AMM.

## Virtual Reserves

No matter what traders do, they cannot force the reserves of any token $X_i$ to fall below $x_{\min}$.

This means the liquidity provider creating the tick can act as if they have "virtual reserves" of $x_{\min}$ of each of the stablecoins the tick trades and don't actually need to provide those $x_{\min}$ tokens when creating the tick. As in Uniswap V3, this is what allows for the capital efficiency we will discuss below.

## Maximum Token Reserves

We can repeat the above derivation but flip the sign of the square root to find the *maximum* quantity of any given coin in the tick assuming both constraints are binding.

Since, if prices are positive, no coin balance will go above $r$, we can then define

$$x_{\max} = \min\left(r, \frac{k\sqrt{n} + \sqrt{k^2 n - n\left((n-1)r - k\sqrt{n}\right)^2}}{n}\right)$$

and

$$x_{\text{other}} = \frac{\sqrt{n}k - x_{\max}}{n - 1}$$

In terms of trading, this will normally represent the situation where one single coin loses its peg and falls in value, while the other coins remain stable, causing traders to give the AMM as much of that one coin as they can. We call this a single-depeg event.

---

# Interpreting k

If we assume that the most common way things will "go wrong" is a single depeg event of the type described in the section immediately above, then for small enough $k$ we are concentrating liquidity where no coin has yet depegged down to a certain threshold — for example, the area where no coin has depegged to below 99 cents.

Assuming only one coin depegs and the rest stay constant, and that $k$ is small enough that the plane constraint is binding, the depegged coin will have reserves of

$$x_{\text{depeg}} = \frac{k\sqrt{n} + \sqrt{k^2 n - n\left((n-1)r - k\sqrt{n}\right)^2}}{n}$$

and

$$x_{\text{other}} = \frac{k\sqrt{n} - x_{\text{depeg}}}{n - 1}$$

Recall from the section on pricing that the instantaneous price of token $X_j$ with respect to token $X_i$ is

$$\frac{\delta x_i}{\delta x_j} = -\frac{\delta F}{\delta x_j} \bigg/ \frac{\delta F}{\delta x_i} = \frac{r - x_j}{r - x_i}$$

In that case, the tick boundary corresponds to the single token depegging to

$$p_{\text{depeg}} = \frac{r - x_{\text{depeg}}}{r - x_{\text{other}}}$$

We can then invert this to obtain, for a given $p_{\text{depeg}}$, the $k$ such that the boundary kicks in exactly at that depeg price:

$$k_{\text{depeg}}(p_{\text{depeg}}) = r\sqrt{n} - \frac{r(p_{\text{depeg}} + n - 1)}{\sqrt{n(p_{\text{depeg}}^2 + n - 1)}}$$

Note that for large-enough $k$, such as $k_{\max}$, the tick will remain fully in-range as multiple coins depeg all the way to 0, so this interpretation won't be relevant there and we are better of thinking about metrics like maximum portfolio loss assuming all coins but one depeg.

---

# Capital Efficiency

As we derived above, given a plane constant $k$, the LP of a given tick gets to take advantage of virtual reserves

$$x_{\min}(k) = \frac{k\sqrt{n} - \sqrt{k^2 n - n\left((n-1)r - k\sqrt{n}\right)^2}}{n}$$

for each of the $n$ assets. If we assume they create the AMM when reserves are at the equal price point $\vec{q}$, the reserves they would need to provide for each coin in the spherical AMM would be

$$x_{\text{base}} = r\left(1 - \sqrt{\frac{1}{n}}\right)$$

So, assuming prices never diverge enough to push reserves past the boundary of the tick, there is a capital efficiency gain of

$$\frac{x_{\text{base}}}{x_{\text{base}} - x_{\min}(k)}$$

Using the depeg price formula from the prior section, we can compute how much capital efficiency you get by picking a boundary corresponding to a max depeg price of $p$:

$$c_{\text{efficiency}}(p) = \frac{x_{\text{base}}}{x_{\text{base}} - x_{\min}(k_{\text{depeg}}(p))}$$

For example, in the 5-asset case, a depeg limit of \$0.90 corresponds to around a 15x capital efficiency increase, while a limit of \$0.99 corresponds to around a 150x capital efficiency increase.

You can view the interactive graph on Desmos [here]().

---

# Tick Consolidation

## Overview

A full Orbital AMM consists of multiple Orbital ticks with different $k$ values.

In this section, we discuss situations in which multiple ticks can be treated as one for the purposes of trade calculations. This will set us up to construct a global trade invariant for the overall orbital AMM in the next section.

As a reminder, for the sake of simplicity we will assume each tick has only a single LP.

## Consolidation Math

Imagine we have 2 ticks, $T_a$ and $T_b$ with reserves $\vec{x}_a$ and $\vec{x}_b$ and parameters $(r_a, k_a)$ and $(r_b, k_b)$ respectively.

### Case 1: Both Reserves Interior

The simplest case is that both reserves vectors begin and end the trade "interior" to their respective ticks, which is to say, not on the tick boundary — i.e.

$$\vec{x}_a \cdot \vec{v} < k_a \quad \text{and} \quad \vec{x}_b \cdot \vec{v} < k_b$$

In this case, both ticks behave locally like normal spherical AMMs, and it must be that $\vec{r}_a - \vec{x}_a$ is parallel to $\vec{r}_b - \vec{x}_b$, since otherwise at least one of the $x_i$ would have a different price relative to some $x_j$ on the two AMMs, allowing for an arbitrage.

Since by definition $\vec{r}_a = r_a\sqrt{n}\vec{v}$ and $\vec{r}_b = r_b\sqrt{n}\vec{v}$, we can see that $\vec{r}_a - \vec{x}_a$ is parallel to $\vec{r}_b - \vec{x}_b$ if and only if

$$\vec{x}_a = \frac{r_a}{r_b}\vec{x}_b$$

This means the combined reserves of the two AMMs are equal to

$$\vec{x}_a + \vec{x}_b = \left(1 + \frac{r_a}{r_b}\right)\vec{x}_b = (r_a + r_b)\frac{\vec{x}_b}{||\vec{x}_b||}$$

Since our AMM constant is $||\vec{x}|| = r$, we can see that reserves scale with the AMM's radius, and so locally we can treat the two ticks as a single spherical AMM with

$$r_c = r_a + r_b$$

As soon as one of the reserve vectors hits the boundary of its tick, we can no longer treat the two ticks as a single spherical AMM, and must move on to one of the later cases.

### Case 2: Both Reserves on Boundary

Let's say that both ticks start with reserves that are on their boundaries as defined by their plane constants.

Now imagine that they execute a trade $\vec{\Delta}$ such that their reserves move from $\vec{x}$ to $\vec{x}' = \vec{x} + \vec{\Delta}$ after which they are still on their boundaries.

In this case for tick $A$ we have

$$\vec{x}_a \cdot \vec{v} = k_a \quad \text{and} \quad \vec{x}'_a \cdot \vec{v} = (\vec{x}_a + \vec{\Delta}_a) \cdot \vec{v} = k_a + \vec{\Delta}_a \cdot \vec{v} = k_a \Rightarrow \vec{\Delta}_a \cdot \vec{v} = 0$$

This means the trade vector $\vec{\Delta}_a$ must be orthogonal to $\vec{v}$ if tick reserves both start and end on the boundary, and the same must be true for $\vec{\Delta}_b$. In other words, this trade is entirely within the subspace orthogonal to $\vec{v}$.

As we discussed in the section on tick boundary geometry, ticks on their boundaries behave like spherical AMMs in the subspace orthogonal to $\vec{v}$. Because both AMMs have centers parallel to $\vec{v}$, which is orthogonal to every vector in that subspace, we can treat this subspace AMM as having a center of 0, and by similar logic to case 1 it has a radius of

$$s_c = s_a + s_b$$

where from the section on tick boundary geometry we have e.g.

$$s_a = \sqrt{r_a^2 - (k_a - r_a\sqrt{n})^2}$$

---

# Global Trade Invariant

This section describes how we can locally compute trades using all of our ticks simultaneously. It is extremely dense. Your favorite LLM may be of some assistance if you are wanting to parse it.

## Setup

First, note that the tick consolidation section above shows we can consolidate all currently interior ticks into a single spherical tick in $\mathbb{R}^n$, and all currently boundary ticks into another spherical tick in the subspace of $\mathbb{R}^n$ orthogonal to $\vec{v}$. So, for the rest of this section, we will assume we have precisely two ticks, one interior and one boundary.

We call the total reserve vector of our combined Orbital AMM $\vec{x}_{\text{total}}$. As described in the section on polar reserve decomposition, we can break this down into components parallel and orthogonal to $\vec{v} = \frac{1}{\sqrt{n}}(1, 1, \ldots, 1)$, so

$$\vec{x}_{\text{total}} = \alpha_{\text{total}}\vec{v} + \vec{w}_{\text{total}}$$

for some $\vec{w}_{\text{total}} \perp \vec{v}$.

We do the same for our consolidated and boundary ticks:

$$\vec{x}_{\text{int}} = \alpha_{\text{int}}\vec{v} + \vec{w}_{\text{int}}$$

$$\vec{x}_{\text{bound}} = \alpha_{\text{bound}}\vec{v} + \vec{w}_{\text{bound}}$$

and because $x_{\text{total}} = x_{\text{int}} + x_{\text{bound}}$, we must have

$$\alpha_{\text{total}} = \alpha_{\text{int}} + \alpha_{\text{bound}}$$

$$\vec{w}_{\text{total}} = \vec{w}_{\text{int}} + \vec{w}_{\text{bound}}$$

## Finding alpha_bound and alpha_int

We know that the boundary reserves $\vec{x}_{\text{bound}}$ must satisfy

$$\vec{x}_{\text{bound}} \cdot \vec{v} = k_{\text{bound}}$$

by definition, since a boundary AMM always has its reserves on the boundary as defined by its plane constraint.

By the polar reserve decomposition, we also have

$$\vec{x}_{\text{bound}} \cdot \vec{v} = (\alpha_{\text{bound}}\vec{v} + \vec{w}_{\text{bound}}) \cdot \vec{v} = \alpha_{\text{bound}}$$

so that

$$\alpha_{\text{bound}} = k_{\text{bound}}$$

Since

$$\alpha_{\text{total}} = \alpha_{\text{int}} + \alpha_{\text{bound}}$$

we then have that

$$\alpha_{\text{int}} = \alpha_{\text{total}} - \alpha_{\text{bound}} = \vec{x}_{\text{total}} \cdot \vec{v} - k_{\text{bound}}$$

## Showing w_int and w_bound are parallel

Construct an orthonormal basis $\vec{z}_1, \ldots, \vec{z}_{n-1}$ for the subspace orthogonal to $\vec{v}$. Together with $\vec{v}$, this constitutes an orthonormal basis for our entire reserve space, where each basis element represents some basket of the constituent stablecoins in different proportions.

Since this is just a rotation of the axes, our interior tick is still a spherical AMM between all of these new basis vectors, and our boundary tick, being a spherical AMM in the subspace orthogonal to $\vec{v}$, is a spherical AMM between all the basis vectors of that subspace, $\vec{z}_1, \ldots, \vec{z}_{n-1}$.

From this, we can see that the interior tick and boundary tick must hold the $\vec{z}_i$ in equal proportions, since otherwise there would be some $i$ and $j$ for which the price of the bundle $\vec{z}_i$ was different to the price of the bundle $\vec{z}_j$ on the boundary and interior ticks, which would present an arbitrage opportunity.

Since the $\vec{z}_i$ form a complete basis for the subspace of reserve space orthogonal to $\vec{v}$, this implies that $\vec{w}_{\text{int}}$ must in fact be parallel to $\vec{w}_{\text{bound}}$.

## Finding ||w_int||

Recall from the section on tick boundary geometry that

$$||\vec{w}_{\text{bound}}||^2 = s_{\text{bound}}^2 = r_{\text{bound}}^2 - (k_{\text{bound}} - r_{\text{bound}}\sqrt{n})^2$$

Since, as we showed in the previous subsection, $\vec{w}_{\text{int}}$ is parallel to $\vec{w}_{\text{bound}}$, the length of their sum is simply the sum of their lengths, so

$$||\vec{w}_{\text{total}}|| = ||\vec{w}_{\text{int}}|| + ||\vec{w}_{\text{bound}}||$$

Substituting in, we then obtain

$$||\vec{w}_{\text{int}}|| = ||\vec{w}_{\text{total}}|| - ||\vec{w}_{\text{bound}}|| = ||\vec{x}_{\text{total}} - (\vec{x}_{\text{total}} \cdot \vec{v})\vec{v}|| - \sqrt{r_{\text{bound}}^2 - (k_{\text{bound}} - r_{\text{bound}}\sqrt{n})^2}$$

## The Full Invariant

Our interior tick's sphere invariant is

$$r_{\text{int}}^2 = ||\vec{r}_{\text{int}} - \vec{x}_{\text{int}}||^2$$

by the Pythagorean theorem, this implies

$$r_{\text{int}}^2 = ||\vec{r}_{\text{int}} - \alpha_{\text{int}}\vec{v}||^2 + ||\vec{w}_{\text{int}}||^2 = (\alpha_{\text{int}} - r_{\text{int}}\sqrt{n})^2||\vec{v}||^2 + ||\vec{w}_{\text{int}}||^2$$

Substituting in our results from the previous sections and simplifying, we then obtain our full invariant

$$r_{\text{int}}^2 = \left((\vec{x}_{\text{total}} \cdot \vec{v} - k_{\text{bound}}) - r_{\text{int}}\sqrt{n}\right)^2 + \left(||\vec{x}_{\text{total}} - (\vec{x}_{\text{total}} \cdot \vec{v})\vec{v}|| - \sqrt{r_{\text{bound}}^2 - (k_{\text{bound}} - r_{\text{bound}}\sqrt{n})^2}\right)^2$$

Note this is equivalent to the formula for a generalized torus, a higher-dimensional extension of the familiar donut shape. Intuitively, this is because we are "adding together" the liquidity from the interior tick, a full sphere, with the liquidity from the boundary tick, a lower-dimensional sphere in a subspace, just the same way as a donut is constructed by centering a sphere over every point on a circle.

## Computation

We can directly compute this invariant as

$$r_{\text{int}}^2 = \left(\frac{1}{\sqrt{n}}\sum_{i=1}^{n} x_{\text{int}_i} - k_{\text{bound}} - r_{\text{int}}\sqrt{n}\right)^2 + \left(\sqrt{\sum_{i=1}^{n} x_{\text{total}_i}^2 - \frac{1}{n}\left(\sum_{i=1}^{n} x_{\text{total}_i}\right)^2} - \sqrt{r_{\text{bound}}^2 - (k_{\text{bound}} - r_{\text{bound}}\sqrt{n})^2}\right)^2$$

Implementations of orbital should keep track of the sums of reserves and squared reserves that appear in that expression.

Since trades of one token for another affect only two of terms in those sums, we can compute the invariant for trades in constant time regardless of the number of dimensions $n$.

---

# Trading Within Tick Boundaries

## Logic

Now that we have the global trade invariant, it is straightforward to compute trades.

Let's say a user provides $d$ units of asset $i$ to the AMM and wants to exchange it for as much of asset $j$ as they can get.

Starting from some valid reserve state $\vec{x}_{\text{total}}$, we simply update the value of $x_i$ to $x_i + d$ and then solve for the $x_j$ that satisfies the global invariant while leaving all other asset balances the same. If there are multiple solutions, we choose the one that leaves the ending balances of $x_j$ below the centers of both the interior and boundary ticks.

This is a quartic equation in $x_j$, which we can solve easily onchain using Newton's method. As mentioned above, if we explicitly track sums in the AMM, the complexity of the equation remains constant time regardless of the number of dimensions in the AMM.

---

# Crossing Ticks

The global trade invariant we derived in the previous section assumes that ticks maintain their status as either "interior" or "boundary."

However, during trades, the system's state can change in a way that causes a previously interior tick's reserves to become pinned at its boundary (or vice versa). In that case, we need to remove the tick from the consolidated boundary (interior) tick, and add it to the consolidated interior (boundary) tick, and then update the torus formula accordingly.

In this section, we'll explain how to detect when these crossings happen and how to handle them by breaking the trades that cause them into segments.

## Intuition

Imagine we have several ticks of different sizes, each one a sphere intersected by a plane determined by that tick's plane constant. These spheres might be different sizes depending on their respective radii, but we could imagine "zooming in" or "zooming out" on the spheres so that they all appeared to be the same size, perhaps represented by a radius of 1.

If we were to do this, we would see something interesting: all of the ticks that are currently "interior," i.e. all the ticks whose reserves are not precisely on their plane boundary, would appear to have their reserves at exactly the same point on the sphere. Geometrically, we can say this is because the spheres are *similar*. In terms of trading, we can say, as above, that this is because otherwise there would be an arbitrage opportunity between the ticks.

Furthermore, ticks have their reserves trapped on their plane boundary and become boundary ticks precisely when this common reserve point strays farther from the equal price point than that tick's plane boundary.

So, in order to trade across ticks, we just compute the trade assuming no ticks have moved from interior to boundary as described in the section on within-tick trades. Then we check the new common interior reserve point and see if it has crossed over the plane boundary of either the closest interior tick or the closest boundary tick. If it has, we compute the trade exactly up to that boundary point, update the type of the tick that was crossed, and compute the rest of the trade.

## Normalization

We use normalized quantities to compare ticks of different sizes by dividing through by the tick radius.

The *normalized position* is $x^{\text{norm}} = \vec{x}/r$

The *normalized projection* is $\alpha^{\text{norm}} = \vec{x}^{\text{norm}} \cdot \vec{v} = \frac{\vec{x} \cdot \vec{v}}{r}$

The *normalized boundary* is $k^{\text{norm}} = \frac{k}{r}$

Note that if $\alpha^{\text{norm}} = k^{\text{norm}}$ for a given tick, we can multiply both sides by $r$ to remove the normalization and see that the tick is at its boundary.

Suppose that for a given tick we have $\alpha^{\text{norm}} < k^{\text{norm}}$, so that it is an interior tick. By no-arbitrage, its reserve vector $\vec{x}$ will be parallel to the r