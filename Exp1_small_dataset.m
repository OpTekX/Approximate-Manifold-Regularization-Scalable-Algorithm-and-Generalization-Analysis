function res_mean=Exp1_small_dataset(data_name)
    addpath('./methods');
    addpath('./utils');
    rand('state', 0)
    totally=tic();
    %% Parameters ----------
    options = parameters(data_name);
    train_fraction=0.7;
    labeled_fraction=0.1;

    %% Load Data ----------
    dataset_path=['./datasets/', data_name];
    [y, X]=libsvmread(dataset_path);

    %% Data split ----------    
    all_idx=randperm(length(y), length(y));
    test_idx=all_idx(1:ceil((1-train_fraction)*length(all_idx)));
    X_test=X(test_idx,:);
    y_test=y(test_idx);

    train_idx=setdiff(all_idx,test_idx);
    X_train=X(train_idx,:);
    y_train=y(train_idx);

    clear X;
    clear all_idx;
    clear train_idx;
    clear test_idx;

    %% Generating grapha Laplacian L and predefinition of kernel----------
    L=construct_laplacian_graph(data_name, X_train, options.NN);
    kernel=load_kernel(data_name, length(y), options.KernelParam);

    times=5;
    res_RLS=[];
    res_LapRLS=[];
    res_LapRLS_pcg=[];
    res_nystrom=[];
    res_nystrom_pcg=[];
    for t=1:times
        %% Preprocess ----------
        train_size=length(y_train);
        labeled_unsorted=randperm(train_size, ceil(labeled_fraction*train_size));
        unlabeled_idx=setdiff(1:train_size, labeled_unsorted);
        labeled_idx=setdiff(1:train_size, unlabeled_idx);
        sample_idx=1:ceil(4*sqrt(train_size));
        
%         labeled_sample_fraction=1;4/sqrt(labeled_fraction*train_fraction*length(y));
%         unlabeled_sample_fraction=4/sqrt((1-labeled_fraction)*train_fraction*length(y));
%         labeled_sample_idx=labeled_idx(1:ceil(labeled_sample_fraction*length(labeled_idx)));
%         unlabeled_sample_idx=unlabeled_idx(1:ceil(unlabeled_sample_fraction*length(unlabeled_idx)));
%         sample_idx=sort([labeled_sample_ idx, unlabeled_sample_idx]);

        K_nn=kernel(X_train, 1:length(y_train), X_train, 1:length(y_train), t, 'knn');
        K_tn=kernel(X_test, 1:length(y_test), X_train, 1:length(y_train), t, 'ktn');

        K_mm=K_nn(labeled_idx, labeled_idx);
        K_tm=K_tn(:,labeled_idx);
        K_ns=K_nn(:,sample_idx);
        K_ss=K_nn(sample_idx,sample_idx)+1e-6*eye(length(sample_idx));

        vectors = struct('labeled_idx',labeled_idx, ...
            'unlabeled_idx',unlabeled_idx, ...
            'sample_idx',sample_idx,...
            'y_train',y_train,...
            'y_test',y_test);

        result=zeros(5,4);
        [result(1,1), result(1,2), result(1,3), result(1,4)] = Method_RLS(K_mm, K_tm, vectors, options);
        [result(2,1), result(2,2), result(2,3), result(2,4)] = Method_LapRLS(K_nn, K_tn, L, vectors, options);
        [result(3,1), result(3,2), result(3,3), result(3,4)] = Method_LapRLS_PCG(K_nn, K_tn,K_ns, K_ss, L, vectors, options);
        [result(4,1), result(4,2), result(4,3), result(4,4)] = Method_LapRLS_Nystrom(K_ns, K_ss, K_tn, L, vectors, options);
        [result(5,1), result(5,2), result(5,3), result(5,4)] = Method_LapRLS_Nystrom_PCG(K_ns, K_ss, K_tn, L, vectors, options);
        
        res_RLS=[res_RLS;result(1,:)];
        res_LapRLS=[res_LapRLS;result(2,:)];
        res_LapRLS_pcg=[res_LapRLS_pcg;result(3,:)];
        res_nystrom=[res_nystrom;result(4,:)];
        res_nystrom_pcg=[res_nystrom_pcg;result(5,:)];
        disp(result);
        clear K_nn K_tn K_mm K_tm K_ns K_ss 
    end
    res_mean=[mean(res_RLS); mean(res_LapRLS); mean(res_LapRLS_pcg); mean(res_nystrom); mean(res_nystrom_pcg)];
    res_std=[std(res_RLS); std(res_LapRLS); std(res_LapRLS_pcg); std(res_nystrom); std(res_nystrom_pcg)];
    tmp=[res_RLS(:,1)-res_LapRLS_pcg(:,1), res_LapRLS(:,1)-res_LapRLS_pcg(:,1), res_LapRLS_pcg(:,1)-res_LapRLS_pcg(:,1), res_nystrom(:,1)-res_LapRLS_pcg(:,1), res_nystrom_pcg(:,1)-res_LapRLS_pcg(:,1)];
    mean(tmp)./std(tmp)*sqrt(50);
    save(['./result/',data_name], 'res_mean', 'res_RLS', 'res_LapRLS', 'res_LapRLS_pcg', 'res_nystrom', 'res_nystrom_pcg', 'res_std');
    disp(['totally cost ', num2str(toc(totally))]);
    disp(res_mean);
end