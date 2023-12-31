package main

import (
	"flag"
	"os"

	"github.com/miaojuncn/sts-webhook/pkg"
	appsv1 "k8s.io/api/apps/v1"
	"k8s.io/klog/v2/klogr"
	"sigs.k8s.io/controller-runtime/pkg/builder"
	"sigs.k8s.io/controller-runtime/pkg/client/config"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/manager"
	"sigs.k8s.io/controller-runtime/pkg/manager/signals"
	"sigs.k8s.io/controller-runtime/pkg/metrics/server"
	"sigs.k8s.io/controller-runtime/pkg/webhook"
)

var (
	setupLog = log.Log.WithName("setup")
)

func main() {

	var (
		certDir              string
		port                 int
		enableLeaderElection bool
	)

	flag.IntVar(&port, "port", 9443, "pod-admission-webhook listen port.")
	flag.StringVar(&certDir, "cert-dir", "", "CertDir is the directory that contains the server key and certificate.")
	flag.BoolVar(&enableLeaderElection, "leader-elect", false, "Enable leader election for controller manager.")

	flag.Parse()
	log.SetLogger(klogr.New())

	mgr, err := manager.New(config.GetConfigOrDie(), manager.Options{
		Metrics: server.Options{
			BindAddress: "0",
		},
		LeaderElection: enableLeaderElection,
		WebhookServer: webhook.NewServer(webhook.Options{
			Port:    port,
			CertDir: certDir,
		}),
	})
	if err != nil {
		setupLog.Error(err, "unable to start manager")
		os.Exit(1)
	}

	if err := builder.WebhookManagedBy(mgr).
		For(&appsv1.StatefulSet{}).
		WithDefaulter(&pkg.StatefulSetVolume{Client: mgr.GetClient()}).
		Complete(); err != nil {
		setupLog.Error(err, "unable to create webhook", "webhook", "sts-webhook")
		os.Exit(1)
	}

	setupLog.Info("starting manager")
	if err := mgr.Start(signals.SetupSignalHandler()); err != nil {
		setupLog.Error(err, "problem running manager")
		os.Exit(1)
	}
}
