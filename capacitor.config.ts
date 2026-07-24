import { CapacitorConfig } from '@capacitor/cli';

const config: CapacitorConfig = {
  appId: 'com.gwentofier.app',
  appName: 'Gwentofier RPG',
  webDir: 'public',
  server: {
    // Aponta para o deploy live: qualquer git push atualiza o app do jogador na hora!
    url: 'https://gwentofier-sigma.vercel.app',
    cleartext: false,
    allowNavigation: ['gwentofier-sigma.vercel.app', '*.supabase.co']
  },
  android: {
    allowMixedContent: true,
    backgroundColor: '#09090b', // bg-zinc-950
    buildOptions: {
      keystorePath: undefined,
      keystoreAlias: undefined
    }
  },
  plugins: {
    SplashScreen: {
      launchShowDuration: 2000,
      backgroundColor: '#09090b',
      showSpinner: false,
      androidSplashResourceName: 'splash'
    }
  }
};

export default config;
