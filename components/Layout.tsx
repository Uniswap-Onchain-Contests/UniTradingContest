import Head from 'next/head'
import { PropsWithChildren } from 'react'

type LayoutProps = Record<string, unknown>

export default function Layout({children}: PropsWithChildren<LayoutProps>) {
	return (
		<>
		<Head>
		<meta charSet="utf-8" />
		<title>Uniswap trading competition</title>
		<meta name="viewport" content="width=device-width,initial-scale=1" />
		</Head>
		<main>
		{children}
		</main>
		</>
	)
}
